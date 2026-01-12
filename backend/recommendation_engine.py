"""
Dynamic Recommendation Engine for ENERGIA

Generates personalized, context-aware recommendations for different user roles
based on real-time data, historical patterns, predictions, and anomalies.
"""
from __future__ import annotations

import os
import sys
import importlib
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Optional
from enum import Enum

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


class RecommendationPriority(str, Enum):
    CRITICAL = "critical"  # Red
    HIGH = "high"  # Orange
    MEDIUM = "medium"  # Yellow
    LOW = "low"  # Blue
    INFO = "info"  # Gray


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
    ):
        self.id = f"{rec_type.value}_{datetime.now().timestamp()}"
        self.title = title
        self.message = message
        self.type = rec_type.value
        self.priority = priority.value
        self.action = action
        self.data = data or {}
        self.icon = icon
        self.timestamp = datetime.now(timezone.utc).isoformat()

    def to_dict(self) -> Dict:
        return {
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


class RecommendationEngine:
    def __init__(self, db_url: str):
        self.engine = create_engine(db_url)

    def get_recommendations(
        self,
        user_role: str,
        user_id: Optional[int] = None,
        department: Optional[str] = None,
        classroom: Optional[str] = None,
    ) -> List[Dict]:
        """Generate recommendations based on user role and context."""
        recommendations = []

        if user_role == "admin":
            recommendations.extend(self._get_admin_recommendations())
        elif user_role == "coordinator":
            recommendations.extend(
                self._get_coordinator_recommendations(department)
            )
        elif user_role == "student" or user_role == "class_representative":
            recommendations.extend(
                self._get_class_rep_recommendations(classroom, department)
            )

        # Sort by priority
        priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4}
        recommendations.sort(key=lambda x: priority_order.get(x["priority"], 5))

        return recommendations

    def _get_admin_recommendations(self) -> List[Dict]:
        """Generate recommendations for administrators."""
        recs = []

        # Check overall campus energy usage
        campus_usage = self._get_campus_energy_stats()
        if campus_usage:
            if campus_usage.get("total_usage", 0) > 1000:  # kWh threshold
                recs.append(
                    Recommendation(
                        title="High Campus Energy Usage",
                        message=f"Total campus usage is {campus_usage['total_usage']:.1f} kWh. Consider implementing energy-saving measures across departments.",
                        rec_type=RecommendationType.IMMEDIATE,
                        priority=RecommendationPriority.HIGH,
                        action="Review department-wise breakdown",
                        data=campus_usage,
                        icon="warning",
                    ).to_dict()
                )

        # Check departments with high usage
        dept_stats = self._get_department_statistics()
        for dept in dept_stats:
            if dept.get("avg_usage", 0) > 150:  # kWh per classroom
                recs.append(
                    Recommendation(
                        title=f"{dept['department']} - High Usage Alert",
                        message=f"Average usage: {dept['avg_usage']:.1f} kWh per classroom. Review with coordinator.",
                        rec_type=RecommendationType.PREVENTIVE,
                        priority=RecommendationPriority.MEDIUM,
                        action=f"Contact {dept['department']} coordinator",
                        data=dept,
                        icon="trending_up",
                    ).to_dict()
                )

        # Check inactive sensors
        inactive_sensors = self._get_inactive_sensors()
        if inactive_sensors and len(inactive_sensors) > 0:
            recs.append(
                Recommendation(
                    title="Inactive Sensors Detected",
                    message=f"{len(inactive_sensors)} sensors haven't reported in 24 hours. Check hardware.",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.CRITICAL,
                    action="View sensor status",
                    data={"sensors": inactive_sensors},
                    icon="sensors_off",
                ).to_dict()
            )

        # Check user registrations
        pending_users = self._get_pending_users()
        if pending_users > 0:
            recs.append(
                Recommendation(
                    title="Pending User Registrations",
                    message=f"{pending_users} users need approval. Review and approve pending registrations.",
                    rec_type=RecommendationType.INFORMATIONAL,
                    priority=RecommendationPriority.LOW,
                    action="Review pending users",
                    data={"count": pending_users},
                    icon="person_add",
                ).to_dict()
            )

        # System optimization suggestions
        if not recs or len(recs) < 2:
            recs.append(
                Recommendation(
                    title="System Running Smoothly",
                    message="All systems operational. Consider reviewing monthly reports for optimization opportunities.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.INFO,
                    action="View reports",
                    icon="check_circle",
                ).to_dict()
            )

        return recs

    def _get_coordinator_recommendations(
        self, department: Optional[str]
    ) -> List[Dict]:
        """Generate recommendations for coordinators."""
        recs = []

        if not department:
            return recs

        # Check classrooms in department
        classroom_stats = self._get_classroom_stats(department)
        
        # High usage classrooms
        high_usage = [c for c in classroom_stats if c.get("usage", 0) > 100]
        if high_usage:
            for classroom in high_usage[:3]:  # Top 3
                recs.append(
                    Recommendation(
                        title=f"{classroom['name']} - High Energy Usage",
                        message=f"Current: {classroom['usage']:.1f} kWh. Contact class rep to review usage patterns.",
                        rec_type=RecommendationType.IMMEDIATE,
                        priority=RecommendationPriority.HIGH,
                        action=f"Contact {classroom['name']} rep",
                        data=classroom,
                        icon="bolt",
                    ).to_dict()
                )

        # Anomalies in department
        anomalies = self._get_recent_anomalies(department=department)
        if anomalies and len(anomalies) > 0:
            recs.append(
                Recommendation(
                    title=f"{len(anomalies)} Anomalies Detected",
                    message=f"Unusual patterns detected in {department}. Review and take action.",
                    rec_type=RecommendationType.PREVENTIVE,
                    priority=RecommendationPriority.MEDIUM,
                    action="View anomaly details",
                    data={"anomalies": anomalies},
                    icon="warning_amber",
                ).to_dict()
            )

        # Check class rep activity
        inactive_reps = self._get_inactive_class_reps(department)
        if inactive_reps and len(inactive_reps) > 0:
            recs.append(
                Recommendation(
                    title="Inactive Class Representatives",
                    message=f"{len(inactive_reps)} reps haven't logged in recently. Follow up with them.",
                    rec_type=RecommendationType.INFORMATIONAL,
                    priority=RecommendationPriority.LOW,
                    action="View inactive reps",
                    data={"reps": inactive_reps},
                    icon="person_off",
                ).to_dict()
            )

        # Weekly summary suggestion
        if datetime.now().weekday() == 4:  # Friday
            recs.append(
                Recommendation(
                    title="Weekly Summary Available",
                    message=f"Review {department}'s weekly energy report and share with class reps.",
                    rec_type=RecommendationType.INFORMATIONAL,
                    priority=RecommendationPriority.INFO,
                    action="Generate report",
                    icon="summarize",
                ).to_dict()
            )

        # Optimization suggestions
        efficiency_score = self._calculate_department_efficiency(department)
        if efficiency_score and efficiency_score < 70:
            recs.append(
                Recommendation(
                    title="Low Efficiency Score",
                    message=f"{department} efficiency: {efficiency_score:.0f}%. Implement energy-saving practices.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.MEDIUM,
                    action="View optimization tips",
                    data={"score": efficiency_score},
                    icon="eco",
                ).to_dict()
            )

        return recs

    def _get_class_rep_recommendations(
        self, classroom: Optional[str], department: Optional[str]
    ) -> List[Dict]:
        """Generate recommendations for class representatives."""
        recs = []

        # Get prediction data
        prediction = self._get_latest_prediction()
        if prediction:
            predicted_value = prediction.get("predicted_energy", 0)
            
            if predicted_value > 5.0:
                recs.append(
                    Recommendation(
                        title="High Usage Predicted",
                        message=f"Next 15 min: {predicted_value:.2f} kWh expected. Turn off non-essential equipment.",
                        rec_type=RecommendationType.PREDICTIVE,
                        priority=RecommendationPriority.CRITICAL,
                        action="View prediction details",
                        data=prediction,
                        icon="trending_up",
                    ).to_dict()
                )
            elif predicted_value > 3.5:
                recs.append(
                    Recommendation(
                        title="Moderate Usage Predicted",
                        message=f"Next 15 min: {predicted_value:.2f} kWh. Monitor usage closely.",
                        rec_type=RecommendationType.PREDICTIVE,
                        priority=RecommendationPriority.MEDIUM,
                        action="View prediction",
                        data=prediction,
                        icon="show_chart",
                    ).to_dict()
                )

        # Current usage check
        current_usage = self._get_current_usage(classroom)
        if current_usage and current_usage > 4.0:
            recs.append(
                Recommendation(
                    title="Current Usage High",
                    message=f"Current: {current_usage:.2f} kW. Check AC, lights, and projector settings.",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.HIGH,
                    action="Quick checklist",
                    data={"current": current_usage},
                    icon="power",
                ).to_dict()
            )

        # Time-based recommendations
        hour = datetime.now().hour
        
        if 17 <= hour <= 19:  # Evening
            recs.append(
                Recommendation(
                    title="Evening Energy Check",
                    message="Classes ending soon. Ensure lights and AC are turned off before leaving.",
                    rec_type=RecommendationType.PREVENTIVE,
                    priority=RecommendationPriority.MEDIUM,
                    action="View checklist",
                    icon="nightlight",
                ).to_dict()
            )
        elif 6 <= hour <= 8:  # Morning
            recs.append(
                Recommendation(
                    title="Morning Setup",
                    message="Turn on only necessary equipment. Natural lighting available.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.LOW,
                    action="Energy tips",
                    icon="wb_sunny",
                ).to_dict()
            )

        # Compare with average
        avg_usage = self._get_average_usage(classroom, department)
        if current_usage and avg_usage and current_usage > avg_usage * 1.3:
            recs.append(
                Recommendation(
                    title="Usage Above Average",
                    message=f"Current usage is 30% above normal ({avg_usage:.1f} kW). Review equipment status.",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.HIGH,
                    action="View breakdown",
                    data={"current": current_usage, "average": avg_usage},
                    icon="compare_arrows",
                ).to_dict()
            )

        # Occupancy-based
        is_occupied = self._check_occupancy(classroom)
        if not is_occupied and current_usage and current_usage > 1.0:
            recs.append(
                Recommendation(
                    title="Empty Classroom Alert",
                    message="No occupancy detected but equipment running. Turn off AC and lights.",
                    rec_type=RecommendationType.IMMEDIATE,
                    priority=RecommendationPriority.CRITICAL,
                    action="Quick shutdown",
                    icon="meeting_room",
                ).to_dict()
            )

        # Daily summary
        if 16 <= hour <= 17:  # Late afternoon
            daily_total = self._get_daily_total(classroom)
            if daily_total:
                recs.append(
                    Recommendation(
                        title="Today's Summary",
                        message=f"Total usage today: {daily_total:.1f} kWh. Review consumption patterns.",
                        rec_type=RecommendationType.INFORMATIONAL,
                        priority=RecommendationPriority.INFO,
                        action="View graphs",
                        data={"total": daily_total},
                        icon="assessment",
                    ).to_dict()
                )

        # Best practices
        if len(recs) < 2:
            recs.append(
                Recommendation(
                    title="Energy Efficiency Tip",
                    message="Set AC to 24°C for optimal balance between comfort and efficiency.",
                    rec_type=RecommendationType.OPTIMIZATION,
                    priority=RecommendationPriority.INFO,
                    action="More tips",
                    icon="lightbulb",
                ).to_dict()
            )

        return recs

    # Helper methods to fetch data from database
    
    def _get_campus_energy_stats(self) -> Optional[Dict]:
        """Get overall campus energy statistics."""
        try:
            with self.engine.begin() as conn:
                result = conn.execute(
                    text("""
                        SELECT 
                            COUNT(*) as total_sensors,
                            SUM(energy) as total_usage,
                            AVG(power) as avg_power
                        FROM pzem_readings
                        WHERE ts >= NOW() - INTERVAL '24 hours'
                    """)
                ).fetchone()
                
                if result:
                    return {
                        "total_sensors": result[0] or 0,
                        "total_usage": result[1] or 0,
                        "avg_power": result[2] or 0,
                    }
        except Exception:
            pass
        return None

    def _get_department_statistics(self) -> List[Dict]:
        """Get statistics by department."""
        try:
            with self.engine.begin() as conn:
                results = conn.execute(
                    text("""
                        SELECT 
                            department,
                            COUNT(*) as classroom_count,
                            AVG(energy) as avg_usage
                        FROM pzem_readings pr
                        JOIN class_representatives cr ON pr.classroom = cr.ktu_id
                        WHERE ts >= NOW() - INTERVAL '24 hours'
                        GROUP BY department
                    """)
                ).fetchall()
                
                return [
                    {
                        "department": row[0],
                        "classroom_count": row[1],
                        "avg_usage": row[2] or 0,
                    }
                    for row in results
                ]
        except Exception:
            pass
        return []

    def _get_inactive_sensors(self) -> List[str]:
        """Get list of sensors that haven't reported recently."""
        # Placeholder - implement based on your sensor tracking
        return []

    def _get_pending_users(self) -> int:
        """Get count of pending user registrations."""
        # Placeholder - implement if you have approval workflow
        return 0

    def _get_classroom_stats(self, department: str) -> List[Dict]:
        """Get classroom statistics for a department."""
        try:
            with self.engine.begin() as conn:
                results = conn.execute(
                    text("""
                        SELECT 
                            cr.ktu_id as name,
                            AVG(pr.power) as usage,
                            MAX(pr.ts) as last_reading
                        FROM class_representatives cr
                        LEFT JOIN pzem_readings pr ON cr.ktu_id = pr.classroom
                        WHERE cr.department = :dept
                        AND pr.ts >= NOW() - INTERVAL '1 hour'
                        GROUP BY cr.ktu_id
                    """),
                    {"dept": department}
                ).fetchall()
                
                return [
                    {
                        "name": row[0],
                        "usage": row[1] or 0,
                        "last_reading": row[2].isoformat() if row[2] else None,
                    }
                    for row in results
                ]
        except Exception:
            pass
        return []

    def _get_recent_anomalies(
        self, department: Optional[str] = None
    ) -> List[Dict]:
        """Get recent anomalies."""
        # Placeholder - integrate with your anomaly detection system
        return []

    def _get_inactive_class_reps(self, department: str) -> List[Dict]:
        """Get class reps who haven't logged in recently."""
        # Placeholder - implement if you track login times
        return []

    def _calculate_department_efficiency(self, department: str) -> Optional[float]:
        """Calculate efficiency score for department."""
        # Placeholder - implement your efficiency calculation
        # Could be based on: usage vs capacity, off-hours usage, etc.
        return None

    def _get_latest_prediction(self) -> Optional[Dict]:
        """Get latest energy prediction."""
        try:
            with self.engine.begin() as conn:
                result = conn.execute(
                    text("""
                        SELECT yhat, yhat_lower, yhat_upper, ds, generated_at
                        FROM prophet_predictions
                        ORDER BY generated_at DESC
                        LIMIT 1
                    """)
                ).fetchone()
                
                if result:
                    return {
                        "predicted_energy": result[0],
                        "lower_bound": result[1],
                        "upper_bound": result[2],
                        "timestamp": result[3].isoformat() if result[3] else None,
                        "generated_at": result[4].isoformat() if result[4] else None,
                    }
        except Exception:
            pass
        return None

    def _get_current_usage(self, classroom: Optional[str]) -> Optional[float]:
        """Get current power usage."""
        if not classroom:
            return None
            
        try:
            with self.engine.begin() as conn:
                result = conn.execute(
                    text("""
                        SELECT power
                        FROM pzem_readings
                        WHERE classroom = :classroom
                        ORDER BY ts DESC
                        LIMIT 1
                    """),
                    {"classroom": classroom}
                ).fetchone()
                
                if result:
                    return result[0]
        except Exception:
            pass
        return None

    def _get_average_usage(
        self, classroom: Optional[str], department: Optional[str]
    ) -> Optional[float]:
        """Get average usage for comparison."""
        try:
            with self.engine.begin() as conn:
                if classroom:
                    result = conn.execute(
                        text("""
                            SELECT AVG(power)
                            FROM pzem_readings
                            WHERE classroom = :classroom
                            AND ts >= NOW() - INTERVAL '7 days'
                        """),
                        {"classroom": classroom}
                    ).fetchone()
                else:
                    result = conn.execute(
                        text("""
                            SELECT AVG(pr.power)
                            FROM pzem_readings pr
                            JOIN class_representatives cr ON pr.classroom = cr.ktu_id
                            WHERE cr.department = :dept
                            AND pr.ts >= NOW() - INTERVAL '7 days'
                        """),
                        {"dept": department}
                    ).fetchone()
                
                if result:
                    return result[0]
        except Exception:
            pass
        return None

    def _check_occupancy(self, classroom: Optional[str]) -> bool:
        """Check if classroom is occupied."""
        # Placeholder - integrate with occupancy sensors if available
        # For now, assume occupied during class hours (9-17)
        hour = datetime.now().hour
        return 9 <= hour <= 17

    def _get_daily_total(self, classroom: Optional[str]) -> Optional[float]:
        """Get total energy usage for today."""
        if not classroom:
            return None
            
        try:
            with self.engine.begin() as conn:
                result = conn.execute(
                    text("""
                        SELECT SUM(energy)
                        FROM pzem_readings
                        WHERE classroom = :classroom
                        AND DATE(ts) = CURRENT_DATE
                    """),
                    {"classroom": classroom}
                ).fetchone()
                
                if result:
                    return result[0]
        except Exception:
            pass
        return None
