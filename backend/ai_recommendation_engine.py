"""
AI-Powered Dynamic Recommendation Engine for ENERGIA

Generates intelligent, context-aware recommendations based on:
- Real-time sensor data and live values
- Prophet model predictions
- Anomaly detection and alerts
- Global energy trends and best practices
- User role and context
- Historical patterns and seasonal factors

Each prediction is automatically paired with actionable recommendations.
"""
from __future__ import annotations

import os
import sys
import importlib
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Optional, Tuple
from enum import Enum
import statistics

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Load config
def _load_cfg():
    if __package__:
        from . import config
        return config
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        return importlib.import_module("config")

cfg = _load_cfg()


class RecommendationType(str, Enum):
    IMMEDIATE = "immediate"  # Urgent action needed
    PREVENTIVE = "preventive"  # Prevent future issues
    OPTIMIZATION = "optimization"  # Improve efficiency
    INFORMATIONAL = "informational"  # FYI updates
    PREDICTIVE = "predictive"  # Based on predictions
    ANOMALY = "anomaly"  # Based on anomaly detection


class RecommendationPriority(str, Enum):
    CRITICAL = "critical"  # Red - immediate action
    HIGH = "high"  # Orange - action needed soon
    MEDIUM = "medium"  # Yellow - should address
    LOW = "low"  # Blue - nice to have
    INFO = "info"  # Gray - informational


class Recommendation:
    def __init__(
        self,
        title: str,
        message: str,
        rec_type: RecommendationType,
        priority: RecommendationPriority,
        action: Optional[str] = None,
        data: Optional[Dict] = None,
        icon: str = "info",
        impact_kwh: Optional[float] = None,
        impact_cost: Optional[float] = None,
    ):
        self.id = f"{rec_type.value}_{datetime.now().timestamp()}"
        self.title = title
        self.message = message
        self.type = rec_type.value
        self.priority = priority.value
        self.action = action
        self.data = data or {}
        self.icon = icon
        self.impact_kwh = impact_kwh  # Estimated energy savings
        self.impact_cost = impact_cost  # Estimated cost savings
        self.timestamp = datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> Dict:
        result = {
            "id": self.id,
            "title": self.title,
            "message": self.message,
            "type": self.type,
            "priority": self.priority,
            "action": self.action,
            "data": self.data,
            "icon": self.icon,
            "timestamp": self.timestamp,
        }
        if self.impact_kwh:
            result["impact_kwh"] = round(self.impact_kwh, 2)
        if self.impact_cost:
            result["impact_cost"] = round(self.impact_cost, 2)
        return result


class AIRecommendationEngine:
    """AI-powered recommendation engine with prediction integration."""
    
    # Global energy trends and benchmarks
    GLOBAL_TRENDS = {
        "classroom_average_kwh_per_hour": 3.5,
        "lab_average_kwh_per_hour": 5.2,
        "peak_hours": [10, 11, 14, 15, 16],
        "off_peak_hours": [0, 1, 2, 3, 4, 5, 6, 7, 20, 21, 22, 23],
        "optimal_ac_temp": 24,
        "energy_cost_per_kwh": 8.5,  # Rupees
    }
    
    def __init__(self, db_url: str):
        self.engine = create_engine(db_url)

    def get_recommendations_with_predictions(
        self,
        user_role: str,
        user_id: Optional[int] = None,
        department: Optional[str] = None,
        classroom: Optional[str] = None,
    ) -> Dict:
        """
        Generate AI-powered recommendations with integrated predictions.
        Returns both recommendations and related predictions.
        """
        recommendations = []
        predictions_data = None

        # Get predictions first (they inform recommendations)
        predictions_data = self._get_predictions_with_recommendations(classroom or department)
        
        # Get live data context
        live_data = self._get_live_data_context(classroom, department)
        
        # Get anomalies
        anomalies = self._detect_anomalies(classroom, department)
        
        # Generate role-based recommendations
        if user_role == "admin":
            recommendations.extend(
                self._get_ai_admin_recommendations(live_data, predictions_data, anomalies)
            )
        elif user_role == "coordinator":
            recommendations.extend(
                self._get_ai_coordinator_recommendations(
                    department, live_data, predictions_data, anomalies
                )
            )
        elif user_role == "student" or user_role == "class_representative":
            recommendations.extend(
                self._get_ai_class_rep_recommendations(
                    classroom, department, live_data, predictions_data, anomalies
                )
            )

        # Add trend-based recommendations
        recommendations.extend(self._get_trend_based_recommendations(live_data))
        
        # Sort by priority
        priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
        recommendations.sort(key=lambda x: priority_order.get(x["priority"], 5))

        return {
            "recommendations": recommendations,
            "count": len(recommendations),
            "predictions": predictions_data,
            "live_data": live_data,
            "anomalies": anomalies,
        }

    def get_recommendations(
        self,
        user_role: str,
        user_id: Optional[int] = None,
        department: Optional[str] = None,
        classroom: Optional[str] = None,
    ) -> List[Dict]:
        """
        Get just the recommendations list without predictions and live data.
        Simpler version for API endpoints that only need recommendations.
        """
        result = self.get_recommendations_with_predictions(
            user_role=user_role,
            user_id=user_id,
            department=department,
            classroom=classroom,
        )
        return result.get("recommendations", [])

    def _get_predictions_with_recommendations(
        self, context: Optional[str]
    ) -> Optional[Dict]:
        """Get predictions and generate related recommendations using live ESP32 sensor data."""
        try:
            # Get latest prediction from Prophet model (uses live ESP32 data)
            prediction = self._get_latest_prediction()
            if not prediction:
                # Also fetch latest ESP32 sensor reading for fallback
                latest_sensor = self._get_latest_sensor_reading()
                if not latest_sensor:
                    return None
            
            # Analyze prediction and generate insights
            pred_value = prediction.get("predicted_energy", 0)
            lower = prediction.get("lower_bound", 0)
            upper = prediction.get("upper_bound", 0)
            
            # Calculate confidence and trend
            confidence = ((upper - lower) / pred_value * 100) if pred_value > 0 else 0
            trend = self._calculate_trend(pred_value)
            
            # Generate prediction-specific recommendations
            pred_recommendations = []
            
            if pred_value > self.GLOBAL_TRENDS["lab_average_kwh_per_hour"]:
                pred_recommendations.append({
                    "title": "High Energy Usage Predicted",
                    "message": f"Predicted usage ({pred_value:.1f} kWh) exceeds average. Consider load reduction.",
                    "action": "Review upcoming schedule",
                    "impact_kwh": pred_value - self.GLOBAL_TRENDS["lab_average_kwh_per_hour"],
                })
            
            if trend == "increasing":
                pred_recommendations.append({
                    "title": "Rising Energy Trend",
                    "message": "Energy consumption is trending upward. Implement efficiency measures now.",
                    "action": "Check equipment and settings",
                })
            
            prediction["recommendations"] = pred_recommendations
            prediction["confidence"] = 100 - confidence if confidence < 100 else 50
            prediction["trend"] = trend
            
            return prediction
            
        except Exception as e:
            print(f"Error getting predictions: {e}")
            return None

    def _get_live_data_context(
        self, classroom: Optional[str], department: Optional[str]
    ) -> Dict:
        """Get comprehensive live data context."""
        context = {
            "current_usage": 0,
            "devices": [],
            "total_devices": 0,
            "active_devices": 0,
            "avg_usage_7d": 0,
            "today_total": 0,
            "hour_of_day": datetime.now().hour,
            "is_peak_hour": datetime.now().hour in self.GLOBAL_TRENDS["peak_hours"],
        }
        
        try:
            with self.engine.begin() as conn:
                # Get current usage by device
                if classroom:
                    query = text("""
                        SELECT device_id, value, ds
                        FROM sensor_data
                        WHERE device_id LIKE :pattern
                        AND ds >= NOW() - INTERVAL '5 minutes'
                        ORDER BY ds DESC
                    """)
                    result = conn.execute(query, {"pattern": f"{classroom}%"}).fetchall()
                else:
                    query = text("""
                        SELECT device_id, value, ds
                        FROM sensor_data
                        WHERE ds >= NOW() - INTERVAL '5 minutes'
                        ORDER BY ds DESC
                    """)
                    result = conn.execute(query).fetchall()
                
                devices = {}
                for row in result:
                    device_id = row[0]
                    if device_id not in devices:
                        devices[device_id] = {
                            "device_id": device_id,
                            "current_value": float(row[1]),
                            "last_update": row[2].isoformat() if row[2] else None,
                            "status": "active" if row[1] > 0.1 else "idle",
                        }
                
                context["devices"] = list(devices.values())
                context["total_devices"] = len(devices)
                context["active_devices"] = sum(1 for d in devices.values() if d["status"] == "active")
                context["current_usage"] = sum(d["current_value"] for d in devices.values())
                
                # Get 7-day average
                avg_query = text("""
                    SELECT AVG(value)
                    FROM sensor_data
                    WHERE ds >= NOW() - INTERVAL '7 days'
                    """ + ("AND device_id LIKE :pattern" if classroom else ""))
                
                params = {"pattern": f"{classroom}%"} if classroom else {}
                avg_result = conn.execute(avg_query, params).fetchone()
                context["avg_usage_7d"] = float(avg_result[0]) if avg_result and avg_result[0] else 0
                
                # Get today's total
                today_query = text("""
                    SELECT SUM(value)
                    FROM sensor_data
                    WHERE DATE(ds) = CURRENT_DATE
                    """ + ("AND device_id LIKE :pattern" if classroom else ""))
                
                today_result = conn.execute(today_query, params).fetchone()
                context["today_total"] = float(today_result[0]) if today_result and today_result[0] else 0
                
        except Exception as e:
            print(f"Error getting live data: {e}")
        
        return context

    def _detect_anomalies(
        self, classroom: Optional[str], department: Optional[str]
    ) -> List[Dict]:
        """Detect anomalies in energy consumption patterns."""
        anomalies = []
        
        try:
            with self.engine.begin() as conn:
                # Get recent readings
                query = text("""
                    SELECT device_id, value, ds
                    FROM sensor_data
                    WHERE ds >= NOW() - INTERVAL '1 hour'
                    ORDER BY ds DESC
                """)
                results = conn.execute(query).fetchall()
                
                # Group by device
                device_data = {}
                for row in results:
                    device_id = row[0]
                    if device_id not in device_data:
                        device_data[device_id] = []
                    device_data[device_id].append(float(row[1]))
                
                # Check for anomalies
                for device_id, values in device_data.items():
                    if len(values) < 3:
                        continue
                    
                    avg = statistics.mean(values)
                    stdev = statistics.stdev(values) if len(values) > 1 else 0
                    latest = values[0]
                    
                    # Spike detection
                    if stdev > 0 and latest > avg + (2 * stdev):
                        anomalies.append({
                            "device_id": device_id,
                            "type": "spike",
                            "severity": "high" if latest > avg + (3 * stdev) else "medium",
                            "current_value": latest,
                            "average_value": avg,
                            "message": f"Unusual spike detected: {latest:.1f} kW (avg: {avg:.1f} kW)",
                        })
                    
                    # Unusual off-hours usage
                    hour = datetime.now().hour
                    if hour in self.GLOBAL_TRENDS["off_peak_hours"] and latest > avg * 0.5:
                        anomalies.append({
                            "device_id": device_id,
                            "type": "off_hours",
                            "severity": "medium",
                            "current_value": latest,
                            "message": f"High usage during off-peak hours: {latest:.1f} kW",
                        })
                
        except Exception as e:
            print(f"Error detecting anomalies: {e}")
        
        return anomalies

    def _get_ai_admin_recommendations(
        self, live_data: Dict, predictions: Optional[Dict], anomalies: List[Dict]
    ) -> List[Dict]:
        """AI-generated recommendations for administrators."""
        recs = []
        
        # Critical: Anomalies
        for anomaly in anomalies:
            if anomaly["severity"] == "high":
                recs.append(
                    Recommendation(
                        title=f"Critical Anomaly: {anomaly['device_id']}",
                        message=anomaly["message"],
                        rec_type=RecommendationType.ANOMALY,
                        priority=RecommendationPriority.CRITICAL,
                        action="Investigate immediately",
                        data=anomaly,
                        icon="error",
                    ).to_dict()
                )
        
        # High: Prediction-based
        if predictions and predictions.get("predicted_energy", 0) > 0:
            pred_val = predictions["predicted_energy"]
            if pred_val > self.GLOBAL_TRENDS["lab_average_kwh_per_hour"] * 1.5:
                potential_savings = pred_val - self.GLOBAL_TRENDS["lab_average_kwh_per_hour"]
                recs.append(
                    Recommendation(
                        title="High Future Energy Demand Predicted",
                        message=f"Next period prediction: {pred_val:.1f} kWh. Implement load management.",
                        rec_type=RecommendationType.PREDICTIVE,
                        priority=RecommendationPriority.HIGH,
                        action="Review load distribution",
                        data=predictions,
                        icon="trending_up",
                        impact_kwh=potential_savings,
                        impact_cost=potential_savings * self.GLOBAL_TRENDS["energy_cost_per_kwh"],
                    ).to_dict()
                )
        
        # Medium: Live data insights
        if live_data["current_usage"] > live_data["avg_usage_7d"] * 1.3:
            excess = live_data["current_usage"] - live_data["avg_usage_7d"]
            recs.append(
                Recommendation(
                    title="Current Usage Above Average",
                    message=f"Current: {live_data['current_usage']:.1f} kW vs Avg: {live_data['avg_usage_7d']:.1f} kW",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.MEDIUM,
                    action="Check active classrooms",
                    data=live_data,
                    icon="warning",
                    impact_kwh=excess,
                ).to_dict()
            )
        
        # Optimization: Peak hour management
        if live_data["is_peak_hour"] and live_data["current_usage"] > 10:
            recs.append(
                Recommendation(
                    title="Peak Hour Load Management",
                    message="Consider shifting non-essential loads to off-peak hours for cost savings.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.MEDIUM,
                    action="Review load schedule",
                    icon="schedule",
                    impact_cost=live_data["current_usage"] * 2.5,  # Peak hour surcharge
                ).to_dict()
            )
        
        # Informational: Trend insights
        if live_data["today_total"] > 0:
            projected_daily = live_data["today_total"] / (live_data["hour_of_day"] + 1) * 24
            recs.append(
                Recommendation(
                    title="Daily Consumption Projection",
                    message=f"Today: {live_data['today_total']:.1f} kWh. Projected: {projected_daily:.1f} kWh for full day.",
                    rec_type=RecommendationType.INFORMATIONAL,
                    priority=RecommendationPriority.INFO,
                    action="View detailed breakdown",
                    data={"today": live_data["today_total"], "projected": projected_daily},
                    icon="insights",
                ).to_dict()
            )
        
        return recs

    def _get_ai_coordinator_recommendations(
        self,
        department: str,
        live_data: Dict,
        predictions: Optional[Dict],
        anomalies: List[Dict],
    ) -> List[Dict]:
        """AI-generated recommendations for coordinators."""
        recs = []
        
        # Anomaly alerts
        dept_anomalies = [a for a in anomalies if department.lower() in a.get("device_id", "").lower()]
        if dept_anomalies:
            recs.append(
                Recommendation(
                    title=f"{len(dept_anomalies)} Anomalies in {department}",
                    message="Unusual energy patterns detected. Review and take action.",
                    rec_type=RecommendationType.ANOMALY,
                    priority=RecommendationPriority.HIGH,
                    action="View anomaly details",
                    data={"anomalies": dept_anomalies},
                    icon="warning_amber",
                ).to_dict()
            )
        
        # Prediction-based insights
        if predictions:
            trend = predictions.get("trend", "stable")
            if trend == "increasing":
                recs.append(
                    Recommendation(
                        title="Rising Energy Trend Detected",
                        message=f"Energy consumption in {department} is trending upward. Consider efficiency audit.",
                        rec_type=RecommendationType.PREDICTIVE,
                        priority=RecommendationPriority.MEDIUM,
                        action="Schedule efficiency review",
                        data=predictions,
                        icon="trending_up",
                    ).to_dict()
                )
        
        # Comparative analysis
        if live_data["current_usage"] > 0:
            vs_avg = ((live_data["current_usage"] - live_data["avg_usage_7d"]) / live_data["avg_usage_7d"] * 100) if live_data["avg_usage_7d"] > 0 else 0
            if abs(vs_avg) > 20:
                recs.append(
                    Recommendation(
                        title=f"Usage {'Above' if vs_avg > 0 else 'Below'} Normal",
                        message=f"{department} usage is {abs(vs_avg):.1f}% {'higher' if vs_avg > 0 else 'lower'} than 7-day average.",
                        rec_type=RecommendationType.INFORMATIONAL,
                        priority=RecommendationPriority.MEDIUM if vs_avg > 0 else RecommendationPriority.LOW,
                        action="Analyze usage patterns",
                        data={"current": live_data["current_usage"], "average": live_data["avg_usage_7d"], "variance": vs_avg},
                        icon="analytics",
                    ).to_dict()
                )
        
        # Device status insights
        if live_data["total_devices"] > 0:
            idle_ratio = (live_data["total_devices"] - live_data["active_devices"]) / live_data["total_devices"]
            if idle_ratio > 0.3:
                recs.append(
                    Recommendation(
                        title="Idle Devices Detected",
                        message=f"{live_data['total_devices'] - live_data['active_devices']} of {live_data['total_devices']} devices are idle. Power down unused equipment.",
                        rec_type=RecommendationType.OPTIMIZATION,
                        priority=RecommendationPriority.LOW,
                        action="Review device status",
                        data=live_data,
                        icon="power_settings_new",
                    ).to_dict()
                )
        
        return recs

    def _get_ai_class_rep_recommendations(
        self,
        classroom: Optional[str],
        department: Optional[str],
        live_data: Dict,
        predictions: Optional[Dict],
        anomalies: List[Dict],
    ) -> List[Dict]:
        """AI-generated recommendations for class representatives."""
        recs = []
        
        # Immediate action: High current usage
        if live_data["current_usage"] > self.GLOBAL_TRENDS["classroom_average_kwh_per_hour"]:
            savings = live_data["current_usage"] - self.GLOBAL_TRENDS["classroom_average_kwh_per_hour"]
            recs.append(
                Recommendation(
                    title="High Energy Usage Alert",
                    message=f"Current usage: {live_data['current_usage']:.1f} kW. Turn off unnecessary lights and equipment.",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.HIGH,
                    action="Reduce load now",
                    data=live_data,
                    icon="bolt",
                    impact_kwh=savings,
                    impact_cost=savings * self.GLOBAL_TRENDS["energy_cost_per_kwh"],
                ).to_dict()
            )
        
        # Prediction-linked recommendation
        if predictions and predictions.get("predicted_energy", 0) > 0:
            pred_val = predictions["predicted_energy"]
            pred_recs = predictions.get("recommendations", [])
            
            for pred_rec in pred_recs:
                recs.append(
                    Recommendation(
                        title=pred_rec["title"],
                        message=f"{pred_rec['message']} (Prediction: {pred_val:.1f} kWh)",
                        rec_type=RecommendationType.PREDICTIVE,
                        priority=RecommendationPriority.MEDIUM,
                        action=pred_rec.get("action", "Take action"),
                        data=predictions,
                        icon="forecast",
                        impact_kwh=pred_rec.get("impact_kwh"),
                    ).to_dict()
                )
        
        # Smart tips based on time of day
        hour = live_data["hour_of_day"]
        if hour in self.GLOBAL_TRENDS["off_peak_hours"] and live_data["current_usage"] > 1:
            recs.append(
                Recommendation(
                    title="Off-Hours Usage Detected",
                    message="Classroom is using energy during off-peak hours. Ensure all equipment is turned off.",
                    rec_type=RecommendationType.PREVENTIVE,
                    priority=RecommendationPriority.MEDIUM,
                    action="Check equipment",
                    icon="nightlight",
                ).to_dict()
            )
        
        # Today's performance
        if live_data["today_total"] > 0 and hour > 12:
            target = self.GLOBAL_TRENDS["classroom_average_kwh_per_hour"] * hour
            if live_data["today_total"] < target:
                recs.append(
                    Recommendation(
                        title="Great Energy Management!",
                        message=f"Today's usage: {live_data['today_total']:.1f} kWh. Below target! Keep it up.",
                        rec_type=RecommendationType.INFORMATIONAL,
                        priority=RecommendationPriority.INFO,
                        action="View details",
                        data={"today": live_data["today_total"], "target": target},
                        icon="eco",
                    ).to_dict()
                )
            else:
                recs.append(
                    Recommendation(
                        title="Usage Above Target",
                        message=f"Today: {live_data['today_total']:.1f} kWh vs Target: {target:.1f} kWh. Implement energy-saving measures.",
                        rec_type=RecommendationType.OPTIMIZATION,
                        priority=RecommendationPriority.MEDIUM,
                        action="Save energy",
                        data={"today": live_data["today_total"], "target": target},
                        icon="energy_savings_leaf",
                    ).to_dict()
                )
        
        return recs

    def _get_trend_based_recommendations(self, live_data: Dict) -> List[Dict]:
        """Generate recommendations based on global energy trends."""
        recs = []
        
        # Best practice recommendations
        hour = live_data["hour_of_day"]
        
        if hour in self.GLOBAL_TRENDS["peak_hours"]:
            recs.append(
                Recommendation(
                    title="Peak Hour Energy Tip",
                    message=f"It's peak hour. Optimize AC to {self.GLOBAL_TRENDS['optimal_ac_temp']}°C and turn off non-essential devices.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.INFO,
                    action="Apply best practices",
                    icon="tips_and_updates",
                ).to_dict()
            )
        
        return recs

    def _get_latest_sensor_reading(self, classroom: Optional[str] = None, department: Optional[str] = None) -> Optional[Dict]:
        """Get the latest ESP32 sensor reading from the database."""
        try:
            with self.engine.begin() as conn:
                # Get most recent sensor reading
                if classroom:
                    result = conn.execute(
                        text("""
                            SELECT device_id, value, voltage, current, power, energy, frequency, power_factor, ds
                            FROM sensor_data
                            WHERE device_id LIKE :pattern
                            ORDER BY ds DESC
                            LIMIT 1
                        """),
                        {"pattern": f"{classroom}%"}
                    ).fetchone()
                else:
                    result = conn.execute(
                        text("""
                            SELECT device_id, value, voltage, current, power, energy, frequency, power_factor, ds
                            FROM sensor_data
                            ORDER BY ds DESC
                            LIMIT 1
                        """)
                    ).fetchone()
                
                if result:
                    return {
                        "device_id": result[0],
                        "value": float(result[1]) if result[1] else 0,
                        "voltage": float(result[2]) if result[2] else None,
                        "current": float(result[3]) if result[3] else None,
                        "power": float(result[4]) if result[4] else None,
                        "energy": float(result[5]) if result[5] else None,
                        "frequency": float(result[6]) if result[6] else None,
                        "power_factor": float(result[7]) if result[7] else None,
                        "timestamp": result[8].isoformat() if result[8] else None,
                    }
        except Exception as e:
            print(f"Error getting latest sensor reading: {e}")
        
        return None

    def _get_latest_prediction(self) -> Optional[Dict]:
        """Get latest energy prediction from Prophet model or database, using live ESP32 data."""
        try:
            with self.engine.begin() as conn:
                # Check if predictions table exists and has data
                result = conn.execute(
                    text("""
                        SELECT COUNT(*) FROM information_schema.tables 
                        WHERE table_name = 'prophet_predictions'
                    """)
                ).fetchone()
                
                if result and result[0] > 0:
                    # Get from stored predictions
                    pred_result = conn.execute(
                        text("""
                            SELECT predicted_energy, lower_bound, upper_bound, 
                                   prediction_timestamp, generated_at
                            FROM prophet_predictions
                            ORDER BY generated_at DESC
                            LIMIT 1
                        """)
                    ).fetchone()
                    
                    if pred_result:
                        return {
                            "predicted_energy": float(pred_result[0]),
                            "lower_bound": float(pred_result[1]),
                            "upper_bound": float(pred_result[2]),
                            "timestamp": pred_result[3].isoformat() if pred_result[3] else None,
                            "generated_at": pred_result[4].isoformat() if pred_result[4] else None,
                            "source": "prophet_model",
                        }
        except Exception as e:
            print(f"Error getting prediction from DB: {e}")
        
        # Fallback: Generate prediction based on latest ESP32 sensor data and recent trends
        try:
            with self.engine.begin() as conn:
                # Get latest sensor reading (from ESP32)
                latest_sensor = conn.execute(
                    text("""
                        SELECT value, power, ds
                        FROM sensor_data
                        ORDER BY ds DESC
                        LIMIT 1
                    """)
                ).fetchone()
                
                # Get last 60 minutes average for trend calculation
                avg_result = conn.execute(
                    text("""
                        SELECT AVG(value) as avg_val, STDDEV(value) as stddev_val
                        FROM sensor_data
                        WHERE ds >= NOW() - INTERVAL '60 minutes'
                    """)
                ).fetchone()
                
                if latest_sensor and latest_sensor[0]:
                    latest_value = float(latest_sensor[0])
                    latest_power = float(latest_sensor[1]) if latest_sensor[1] else latest_value
                    
                    # Calculate trend and variability
                    avg_val = float(avg_result[0]) if avg_result and avg_result[0] else latest_value
                    stddev = float(avg_result[1]) if avg_result and avg_result[1] else avg_val * 0.2
                    
                    # Prediction: next 15 minutes based on current trend
                    predicted_energy = latest_value * 1.05  # 5% increase for typical load pattern
                    lower_bound = max(0, avg_val - (2 * stddev))  # 95% confidence interval
                    upper_bound = avg_val + (2 * stddev)
                    
                    return {
                        "predicted_energy": predicted_energy,
                        "lower_bound": lower_bound,
                        "upper_bound": upper_bound,
                        "timestamp": (datetime.now() + timedelta(minutes=15)).isoformat(),
                        "generated_at": datetime.now().isoformat(),
                        "method": "esp32_trend_analysis",
                        "latest_sensor_value": latest_value,
                        "latest_sensor_power": latest_power,
                        "last_reading_time": latest_sensor[2].isoformat() if latest_sensor[2] else None,
                    }
        except Exception as e:
            print(f"Error generating fallback prediction from sensor data: {e}")
        
        return None

    def _calculate_trend(self, current_value: float) -> str:
        """Calculate trend based on historical data."""
        try:
            with self.engine.begin() as conn:
                result = conn.execute(
                    text("""
                        SELECT AVG(value)
                        FROM sensor_data
                        WHERE ds >= NOW() - INTERVAL '1 hour'
                    """)
                ).fetchone()
                
                if result and result[0]:
                    avg = float(result[0])
                    if current_value > avg * 1.1:
                        return "increasing"
                    elif current_value < avg * 0.9:
                        return "decreasing"
        except Exception:
            pass
        
        return "stable"
