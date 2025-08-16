"""
Database configuration and connection management
"""

import databases
import sqlalchemy
from sqlalchemy import create_engine, MetaData
from .config import get_settings

settings = get_settings()

# Database URL
DATABASE_URL = settings.DATABASE_URL

# Create database instance
database = databases.Database(DATABASE_URL)

# Create SQLAlchemy engine
engine = create_engine(DATABASE_URL)

# Create metadata instance
metadata = MetaData()

# Define tables
collections_table = sqlalchemy.Table(
    "collections",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("name_en", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("name_ar", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("description_en", sqlalchemy.Text),
    sqlalchemy.Column("description_ar", sqlalchemy.Text),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now(), onupdate=sqlalchemy.func.now()),
)

chapters_table = sqlalchemy.Table(
    "chapters",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("collection_id", sqlalchemy.String, sqlalchemy.ForeignKey("collections.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("chapter_number", sqlalchemy.Integer, nullable=False),
    sqlalchemy.Column("title_en", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("title_ar", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("description_en", sqlalchemy.Text),
    sqlalchemy.Column("description_ar", sqlalchemy.Text),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now(), onupdate=sqlalchemy.func.now()),
    sqlalchemy.UniqueConstraint("collection_id", "chapter_number"),
)

hadiths_table = sqlalchemy.Table(
    "hadiths",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("collection_id", sqlalchemy.String, sqlalchemy.ForeignKey("collections.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("chapter_id", sqlalchemy.String, sqlalchemy.ForeignKey("chapters.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("hadith_number", sqlalchemy.Integer, nullable=False),
    sqlalchemy.Column("arabic_text", sqlalchemy.Text, nullable=False),
    sqlalchemy.Column("english_text", sqlalchemy.Text, nullable=False),
    sqlalchemy.Column("narrator", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("grade", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("grade_details", sqlalchemy.Text),
    sqlalchemy.Column("refs", sqlalchemy.JSON),  # JSON field for references
    sqlalchemy.Column("tags", sqlalchemy.JSON),  # JSON field for tags
    sqlalchemy.Column("source_url", sqlalchemy.String),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now(), onupdate=sqlalchemy.func.now()),
    sqlalchemy.UniqueConstraint("collection_id", "hadith_number"),
)

users_table = sqlalchemy.Table(
    "users",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("email", sqlalchemy.String, unique=True, nullable=False),
    sqlalchemy.Column("hashed_password", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("full_name", sqlalchemy.String),
    sqlalchemy.Column("is_active", sqlalchemy.Boolean, default=True),
    sqlalchemy.Column("is_verified", sqlalchemy.Boolean, default=False),
    sqlalchemy.Column("role", sqlalchemy.String, default="user"),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.Column("updated_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now(), onupdate=sqlalchemy.func.now()),
)

favorites_table = sqlalchemy.Table(
    "favorites",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("user_id", sqlalchemy.Integer, sqlalchemy.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("hadith_id", sqlalchemy.String, sqlalchemy.ForeignKey("hadiths.id", ondelete="CASCADE"), nullable=False),
    sqlalchemy.Column("notes", sqlalchemy.Text),
    sqlalchemy.Column("added_at", sqlalchemy.DateTime, server_default=sqlalchemy.func.now()),
    sqlalchemy.UniqueConstraint("user_id", "hadith_id"),
)

# Create indexes
indexes = [
    sqlalchemy.Index("idx_chapters_collection_id", chapters_table.c.collection_id),
    sqlalchemy.Index("idx_hadiths_collection_id", hadiths_table.c.collection_id),
    sqlalchemy.Index("idx_hadiths_chapter_id", hadiths_table.c.chapter_id),
    sqlalchemy.Index("idx_hadiths_grade", hadiths_table.c.grade),
    sqlalchemy.Index("idx_favorites_user_id", favorites_table.c.user_id),
    sqlalchemy.Index("idx_favorites_hadith_id", favorites_table.c.hadith_id),
    sqlalchemy.Index("idx_users_email", users_table.c.email),
]
