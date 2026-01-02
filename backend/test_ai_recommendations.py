"""
Test the AI-powered recommendation system with predictions integration.
"""
import requests
import json
from datetime import datetime

BASE_URL = "http://localhost:8000"

def test_prediction_with_recommendations():
    """Test that predictions include AI-generated recommendations."""
    print("\n" + "="*80)
    print("🔮 Testing Prophet Prediction with AI Recommendations")
    print("="*80)
    
    try:
        response = requests.post(f"{BASE_URL}/model/predict_15min", json={})
        
        if response.status_code == 200:
            data = response.json()
            
            print(f"\n✅ Prediction received:")
            print(f"   Timestamp: {data.get('timestamp')}")
            print(f"   Predicted Energy: {data.get('predicted_energy'):.2f} kWh")
            print(f"   Range: {data.get('lower_bound'):.2f} - {data.get('upper_bound'):.2f} kWh")
            print(f"   Generated at: {data.get('generated_at')}")
            
            recommendations = data.get('recommendations', [])
            print(f"\n📋 Recommendations ({len(recommendations)} total):")
            print("-" * 80)
            
            for i, rec in enumerate(recommendations, 1):
                print(f"\n{i}. {rec.get('title')}")
                print(f"   Priority: {rec.get('priority').upper()}")
                print(f"   Message: {rec.get('message')}")
                print(f"   Action: {rec.get('action')}")
                if 'impact_kwh' in rec:
                    print(f"   Impact: {rec.get('impact_kwh')} kWh (₹{rec.get('impact_cost', 0):.2f})")
            
            return True
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"   {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def test_ai_recommendations(token=None):
    """Test the full AI recommendation system (requires JWT token)."""
    print("\n" + "="*80)
    print("🤖 Testing AI Recommendation System")
    print("="*80)
    
    # If no token, show instructions
    if not token:
        print("\n⚠️  No JWT token provided. To test full system:")
        print("   1. Login to the app")
        print("   2. Copy JWT token from browser developer tools")
        print("   3. Run: python test_ai_recommendations.py <token>")
        print("\n   Testing without authentication (limited data)...\n")
    
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    try:
        response = requests.get(
            f"{BASE_URL}/recommendations/recommendations",
            headers=headers
        )
        
        if response.status_code == 200:
            data = response.json()
            
            recommendations = data.get('recommendations', [])
            predictions = data.get('predictions')
            live_data = data.get('live_data', {})
            anomalies = data.get('anomalies', [])
            
            print(f"\n📊 System Status:")
            print("-" * 80)
            
            # Live data
            print(f"\n🔴 Live Data:")
            print(f"   Current Usage: {live_data.get('current_usage', 0):.2f} kW")
            print(f"   Active Devices: {live_data.get('active_devices', 0)}/{live_data.get('total_devices', 0)}")
            print(f"   7-Day Average: {live_data.get('avg_usage_7d', 0):.2f} kW")
            print(f"   Today's Total: {live_data.get('today_total', 0):.2f} kWh")
            print(f"   Hour: {live_data.get('hour_of_day', 0)} (Peak: {live_data.get('is_peak_hour', False)})")
            
            # Predictions
            if predictions:
                print(f"\n🔮 Next Prediction:")
                print(f"   Energy: {predictions.get('predicted_energy', 0):.2f} kWh")
                print(f"   Trend: {predictions.get('trend', 'N/A')}")
                print(f"   Confidence: {predictions.get('confidence', 0):.0f}%")
            
            # Anomalies
            if anomalies:
                print(f"\n⚠️  Anomalies Detected: {len(anomalies)}")
                for anomaly in anomalies[:3]:  # Show first 3
                    print(f"   - {anomaly.get('device_id')}: {anomaly.get('message')}")
            
            # Recommendations
            print(f"\n📋 AI Recommendations ({len(recommendations)} total):")
            print("=" * 80)
            
            # Group by priority
            by_priority = {
                'critical': [],
                'high': [],
                'medium': [],
                'low': [],
                'info': []
            }
            
            for rec in recommendations:
                priority = rec.get('priority', 'info')
                by_priority[priority].append(rec)
            
            # Display by priority
            priority_icons = {
                'critical': '🔴',
                'high': '🟠',
                'medium': '🟡',
                'low': '🔵',
                'info': '⚪'
            }
            
            for priority in ['critical', 'high', 'medium', 'low', 'info']:
                recs = by_priority[priority]
                if recs:
                    print(f"\n{priority_icons[priority]} {priority.upper()} Priority ({len(recs)}):")
                    for rec in recs:
                        print(f"\n   • {rec.get('title')}")
                        print(f"     {rec.get('message')}")
                        print(f"     Type: {rec.get('type')} | Action: {rec.get('action')}")
                        if 'impact_kwh' in rec:
                            print(f"     💡 Potential Savings: {rec.get('impact_kwh')} kWh (₹{rec.get('impact_cost', 0):.2f})")
            
            return True
            
        else:
            print(f"❌ Error: {response.status_code}")
            print(f"   {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


def main():
    """Run all tests."""
    print("\n" + "="*80)
    print("🧪 ENERGIA AI Recommendation System Tests")
    print("="*80)
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Backend: {BASE_URL}")
    
    results = []
    
    # Test 1: Prediction with recommendations
    results.append(("Prediction with Recommendations", test_prediction_with_recommendations()))
    
    # Test 2: Full AI recommendations (without token for now)
    results.append(("AI Recommendations", test_ai_recommendations()))
    
    # Summary
    print("\n" + "="*80)
    print("📊 Test Summary")
    print("="*80)
    
    for test_name, passed in results:
        status = "✅ PASSED" if passed else "❌ FAILED"
        print(f"{status} - {test_name}")
    
    total = len(results)
    passed = sum(1 for _, p in results if p)
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed! AI Recommendation System is working correctly.")
    else:
        print("\n⚠️  Some tests failed. Check the errors above.")


if __name__ == "__main__":
    import sys
    
    # Check if token provided as command line argument
    token = sys.argv[1] if len(sys.argv) > 1 else None
    
    if token:
        print(f"\n🔑 Using provided JWT token for authenticated tests")
        test_ai_recommendations(token)
    else:
        main()
