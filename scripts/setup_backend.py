#!/usr/bin/env python3
"""
Backend Setup Script - Automates the setup process for the Hadith App backend
"""

import subprocess
import sys
import os
import shutil
from pathlib import Path
import logging
import argparse

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class BackendSetup:
    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.venv_path = project_root / "venv"
        self.requirements_path = project_root / "requirements.txt"
        self.env_path = project_root / ".env"
        self.env_example_path = project_root / "config" / ".env.example"
    
    def check_requirements(self):
        """Check if required tools are installed"""
        logger.info("Checking system requirements...")
        
        required_tools = {
            "python3": "Python 3.8+",
            "pip": "Python package installer",
            "docker": "Docker (optional, for containerized deployment)",
            "psql": "PostgreSQL client (optional, for database management)"
        }
        
        missing_tools = []
        
        for tool, description in required_tools.items():
            if not shutil.which(tool):
                missing_tools.append(f"{tool} - {description}")
        
        if missing_tools:
            logger.warning("Missing optional tools:")
            for tool in missing_tools:
                logger.warning(f"  - {tool}")
        else:
            logger.info("All requirements satisfied!")
        
        return len(missing_tools) == 0
    
    def create_virtual_environment(self):
        """Create Python virtual environment"""
        logger.info("Creating virtual environment...")
        
        if self.venv_path.exists():
            logger.info("Virtual environment already exists")
            return True
        
        try:
            subprocess.run([
                sys.executable, "-m", "venv", str(self.venv_path)
            ], check=True)
            logger.info("Virtual environment created successfully")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create virtual environment: {e}")
            return False
    
    def install_dependencies(self):
        """Install Python dependencies"""
        logger.info("Installing Python dependencies...")
        
        if not self.requirements_path.exists():
            logger.error(f"Requirements file not found: {self.requirements_path}")
            return False
        
        # Determine pip path
        if os.name == 'nt':  # Windows
            pip_path = self.venv_path / "Scripts" / "pip"
        else:  # Unix/Linux/macOS
            pip_path = self.venv_path / "bin" / "pip"
        
        try:
            # Upgrade pip first
            subprocess.run([
                str(pip_path), "install", "--upgrade", "pip"
            ], check=True)
            
            # Install requirements
            subprocess.run([
                str(pip_path), "install", "-r", str(self.requirements_path)
            ], check=True)
            
            logger.info("Dependencies installed successfully")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to install dependencies: {e}")
            return False
    
    def setup_environment_file(self):
        """Set up environment configuration file"""
        logger.info("Setting up environment configuration...")
        
        if self.env_path.exists():
            logger.info("Environment file already exists")
            return True
        
        if not self.env_example_path.exists():
            logger.error(f"Environment example file not found: {self.env_example_path}")
            return False
        
        try:
            # Copy example file
            shutil.copy2(self.env_example_path, self.env_path)
            
            logger.info("Environment file created from example")
            logger.warning("⚠️  Please edit .env file with your actual configuration values!")
            logger.warning("   Especially DATABASE_URL and SECRET_KEY")
            return True
        except Exception as e:
            logger.error(f"Failed to create environment file: {e}")
            return False
    
    def setup_database_schema(self, database_url: str = None):
        """Set up PostgreSQL database schema"""
        logger.info("Setting up database schema...")
        
        schema_path = self.project_root / "database" / "postgresql_schema.sql"
        if not schema_path.exists():
            logger.error(f"Schema file not found: {schema_path}")
            return False
        
        if not database_url:
            logger.info("Database URL not provided, skipping schema setup")
            logger.info("You can run the schema manually with:")
            logger.info(f"  psql $DATABASE_URL -f {schema_path}")
            return True
        
        try:
            subprocess.run([
                "psql", database_url, "-f", str(schema_path)
            ], check=True)
            
            logger.info("Database schema created successfully")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to create database schema: {e}")
            logger.info("You can run the schema manually with:")
            logger.info(f"  psql '{database_url}' -f {schema_path}")
            return False
        except FileNotFoundError:
            logger.warning("psql not found, skipping database setup")
            logger.info("Install PostgreSQL client and run:")
            logger.info(f"  psql '{database_url}' -f {schema_path}")
            return True
    
    def run_tests(self):
        """Run test suite"""
        logger.info("Running test suite...")
        
        # Determine python path
        if os.name == 'nt':  # Windows
            python_path = self.venv_path / "Scripts" / "python"
        else:  # Unix/Linux/macOS
            python_path = self.venv_path / "bin" / "python"
        
        try:
            result = subprocess.run([
                str(python_path), "-m", "pytest", "tests/", "-v"
            ], cwd=self.project_root, capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info("All tests passed!")
                return True
            else:
                logger.warning("Some tests failed:")
                logger.warning(result.stdout)
                logger.warning(result.stderr)
                return False
        except Exception as e:
            logger.error(f"Failed to run tests: {e}")
            return False
    
    def start_development_server(self):
        """Start development server"""
        logger.info("Starting development server...")
        
        # Determine python path
        if os.name == 'nt':  # Windows
            python_path = self.venv_path / "Scripts" / "python"
        else:  # Unix/Linux/macOS
            python_path = self.venv_path / "bin" / "python"
        
        try:
            logger.info("Starting server at http://localhost:8000")
            logger.info("API docs available at http://localhost:8000/docs")
            logger.info("Press Ctrl+C to stop the server")
            
            subprocess.run([
                str(python_path), "-m", "uvicorn", "src.main:app",
                "--host", "0.0.0.0", "--port", "8000", "--reload"
            ], cwd=self.project_root)
            
        except KeyboardInterrupt:
            logger.info("Server stopped")
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
    
    def run_setup(self, database_url: str = None, skip_tests: bool = False, start_server: bool = False):
        """Run complete setup process"""
        logger.info("Starting Hadith App backend setup...")
        
        steps = [
            ("Checking requirements", self.check_requirements),
            ("Creating virtual environment", self.create_virtual_environment),
            ("Installing dependencies", self.install_dependencies),
            ("Setting up environment file", self.setup_environment_file),
        ]
        
        if database_url:
            steps.append(("Setting up database schema", lambda: self.setup_database_schema(database_url)))
        
        if not skip_tests:
            steps.append(("Running tests", self.run_tests))
        
        # Run setup steps
        for step_name, step_func in steps:
            logger.info(f"\n{'='*50}")
            logger.info(f"Step: {step_name}")
            logger.info(f"{'='*50}")
            
            if not step_func():
                logger.error(f"Setup failed at step: {step_name}")
                return False
        
        logger.info(f"\n{'='*50}")
        logger.info("Setup completed successfully! 🎉")
        logger.info(f"{'='*50}")
        
        # Print next steps
        logger.info("\nNext steps:")
        logger.info("1. Edit .env file with your configuration")
        logger.info("2. Set up PostgreSQL database if not done already")
        logger.info("3. Import hadith data using scripts/import_data.py")
        logger.info("4. Start the server with: python -m uvicorn src.main:app --reload")
        
        if start_server:
            input("\nPress Enter to start the development server...")
            self.start_development_server()
        
        return True

def main():
    """Main function with command line arguments"""
    parser = argparse.ArgumentParser(description='Set up Hadith App backend')
    parser.add_argument('--database-url', help='PostgreSQL database URL for schema setup')
    parser.add_argument('--skip-tests', action='store_true', help='Skip running tests')
    parser.add_argument('--start-server', action='store_true', help='Start development server after setup')
    parser.add_argument('--project-root', default='.', help='Project root directory')
    
    args = parser.parse_args()
    
    # Resolve project root
    project_root = Path(args.project_root).resolve()
    
    if not project_root.exists():
        logger.error(f"Project root directory not found: {project_root}")
        sys.exit(1)
    
    # Create setup instance and run
    setup = BackendSetup(project_root)
    success = setup.run_setup(
        database_url=args.database_url,
        skip_tests=args.skip_tests,
        start_server=args.start_server
    )
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
