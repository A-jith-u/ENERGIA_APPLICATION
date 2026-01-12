"""Quick test script for the monthly report API"""
import sys
import os

# Add backend to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

try:
    print("Testing monthly report API import...")
    from backend import monthly_report_api
    print("✓ monthly_report_api imported successfully")
    
    print("\nChecking router endpoints...")
    routes = [route.path for route in monthly_report_api.router.routes]
    print(f"✓ Found {len(routes)} endpoints:")
    for route in routes:
        print(f"  - {route}")
    
    print("\n✓ All imports successful!")
    print("\nBackend monthly report API is ready to use.")
    print("Start the server with: python backend/start_server.py")
    print("Access at: http://localhost:8000/reports/monthly-report")
    
except Exception as e:
    print(f"✗ Error: {e}")
    print("\nMake sure you're running this from the project root directory.")
    print("And that all backend dependencies are installed:")
    print("  pip install -r backend/requirements.txt")
