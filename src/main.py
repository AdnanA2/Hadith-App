#!/usr/bin/env python3
"""
Hadith of the Day - FastAPI Backend
Main application entry point
"""

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
import uvicorn
import os
from typing import Optional

from .database import database, engine, metadata
from .routers import hadiths, favorites, auth, collections
from .config import get_settings

# Initialize security
security = HTTPBearer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await database.connect()
    yield
    # Shutdown
    await database.disconnect()

# Create FastAPI app
app = FastAPI(
    title="Hadith of the Day API",
    description="Backend API for the Hadith of the Day mobile application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Configure CORS
settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router, prefix="/api/v1/auth", tags=["authentication"])
app.include_router(collections.router, prefix="/api/v1/collections", tags=["collections"])
app.include_router(hadiths.router, prefix="/api/v1/hadiths", tags=["hadiths"])
app.include_router(favorites.router, prefix="/api/v1/favorites", tags=["favorites"])

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Hadith of the Day API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Test database connection
        await database.fetch_one("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database connection failed: {str(e)}"
        )

if __name__ == "__main__":
    uvicorn.run(
        "src.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True if os.getenv("ENVIRONMENT") == "development" else False
    )
