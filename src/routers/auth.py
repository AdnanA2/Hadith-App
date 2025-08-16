"""
Authentication router - handles user signup, login, and profile management
"""

from datetime import timedelta
from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import insert, select, update
from sqlalchemy.exc import IntegrityError

from ..database import database, users_table
from ..models import (
    SignupRequest, LoginRequest, AuthResponse, UserResponse,
    User, UserUpdate, Token
)
from ..auth import (
    authenticate_user, create_access_token, get_password_hash,
    get_current_active_user, get_current_user
)
from ..config import get_settings

router = APIRouter()
settings = get_settings()

@router.post("/signup", response_model=AuthResponse)
async def signup(user_data: SignupRequest):
    """Register a new user"""
    
    # Check if user already exists
    existing_user = await database.fetch_one(
        select(users_table).where(users_table.c.email == user_data.email)
    )
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Hash password
    hashed_password = get_password_hash(user_data.password)
    
    # Create user
    try:
        query = insert(users_table).values(
            email=user_data.email,
            hashed_password=hashed_password,
            full_name=user_data.full_name,
            is_active=True,
            is_verified=False,
            role="user"
        )
        user_id = await database.execute(query)
        
        # Fetch created user
        user = await database.fetch_one(
            select(users_table).where(users_table.c.id == user_id)
        )
        
        # Create access token
        access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"sub": user.email}, expires_delta=access_token_expires
        )
        
        token_data = Token(
            access_token=access_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
        )
        
        user_obj = User.model_validate(user)
        
        return AuthResponse(
            message="User created successfully",
            data=token_data,
            user=user_obj
        )
        
    except IntegrityError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

@router.post("/login", response_model=AuthResponse)
async def login(login_data: LoginRequest):
    """Authenticate user and return access token"""
    
    user = await authenticate_user(login_data.email, login_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user account"
        )
    
    # Create access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email}, expires_delta=access_token_expires
    )
    
    token_data = Token(
        access_token=access_token,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )
    
    user_obj = User.model_validate(user)
    
    return AuthResponse(
        message="Login successful",
        data=token_data,
        user=user_obj
    )

@router.get("/me", response_model=UserResponse)
async def get_current_user_profile(current_user: dict = Depends(get_current_active_user)):
    """Get current user profile"""
    user_obj = User.model_validate(current_user)
    return UserResponse(data=user_obj)

@router.put("/me", response_model=UserResponse)
async def update_current_user_profile(
    user_update: UserUpdate,
    current_user: dict = Depends(get_current_active_user)
):
    """Update current user profile"""
    
    update_data = {}
    
    if user_update.full_name is not None:
        update_data["full_name"] = user_update.full_name
    
    if user_update.password is not None:
        update_data["hashed_password"] = get_password_hash(user_update.password)
    
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields to update"
        )
    
    update_data["updated_at"] = "NOW()"
    
    # Update user
    query = (
        update(users_table)
        .where(users_table.c.id == current_user.id)
        .values(**update_data)
    )
    await database.execute(query)
    
    # Fetch updated user
    updated_user = await database.fetch_one(
        select(users_table).where(users_table.c.id == current_user.id)
    )
    
    user_obj = User.model_validate(updated_user)
    return UserResponse(
        message="Profile updated successfully",
        data=user_obj
    )

@router.post("/refresh", response_model=AuthResponse)
async def refresh_token(current_user: dict = Depends(get_current_user)):
    """Refresh access token"""
    
    # Create new access token
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": current_user.email}, expires_delta=access_token_expires
    )
    
    token_data = Token(
        access_token=access_token,
        token_type="bearer",
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60
    )
    
    user_obj = User.model_validate(current_user)
    
    return AuthResponse(
        message="Token refreshed successfully",
        data=token_data,
        user=user_obj
    )
