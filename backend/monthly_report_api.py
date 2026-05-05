"""Monthly Report API for Energia System.
Generates comprehensive monthly reports with energy consumption analytics,
trends, recommendations, and department-wise breakdowns.
"""
import jwt
import traceback
from fastapi import APIRouter, HTTPException, Header, Request
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text, func
from typing import Dict, List, Any
import json
from decimal import Decimal
from fastapi import FastAPI

try:
    # Package mode: started via `python -m backend.app_main` or start_server.py
    from . import config  # type: ignore
except Exception:
    # Script mode: started via `python app_main.py` from backend folder
    import config  # type: ignore

DB_URL = config.get_db_url()
JWT_SECRET = config.get_jwt_secret()
JWT_ALG = "HS256"

app = FastAPI()
router = APIRouter()
engine = create_engine(DB_URL)


def _verify_admin_token(authorization: str | None) -> dict:
    if not authorization:
        print("[monthly_report] DEBUG: No authorization header")
        raise HTTPException(status_code=401, detail="Authentication required")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        print("[monthly_report] DEBUG: Empty token after removing Bearer prefix")
        raise HTTPException(status_code=401, detail="Authentication required")

    try:
        print(f"[monthly_report] DEBUG: Attempting to decode token with secret: {JWT_SECRET[:20]}...")
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
        print(f"[monthly_report] DEBUG: Token decoded successfully. Payload: {payload}")
    except jwt.ExpiredSignatureError as e:
        print(f"[monthly_report] DEBUG: Token expired: {e}")
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.PyJWTError as e:
        print(f"[monthly_report] DEBUG: JWT decode error: {e}")
        raise HTTPException(status_code=401, detail="Invalid token")

    role = (payload.get("role") or "").lower()
    print(f"[monthly_report] DEBUG: User role from token: '{role}'")
    
    if role != "admin":
        print(f"[monthly_report] DEBUG: Role check failed. Expected 'admin', got '{role}'")
        raise HTTPException(status_code=403, detail="Admin access required")

    print(f"[monthly_report] DEBUG: Token verified successfully for user: {payload.get('user_id')}")
    return payload


def _decimal_default(obj):
    """JSON serializer for Decimal objects."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError


@router.get("/monthly-report")
async def get_monthly_report(
    request: Request,
    month: int = None,
    year: int = None,
    report_type: str = "both",
    authorization: str | None = Header(default=None, alias="Authorization"),
):
    """Generate comprehensive monthly report.

    report_type values:
    - normal: user-friendly report
    - technical: detailed technical report
    - both: return both variants plus legacy fields
    """
    try:
        _verify_admin_token(authorization)

        if report_type not in {"normal", "technical", "both"}:
            raise HTTPException(status_code=400, detail="report_type must be normal, technical, or both")

        now = datetime.now()
        target_month = month or now.month
        target_year = year or now.year

        report_start = datetime(target_year, target_month, 1)
        report_end = datetime(target_year + 1, 1, 1) if target_month == 12 else datetime(target_year, target_month + 1, 1)

        if target_month == 1:
            prev_start = datetime(target_year - 1, 12, 1)
            prev_end = datetime(target_year, 1, 1)
        else:
            prev_start = datetime(target_year, target_month - 1, 1)
            prev_end = datetime(target_year, target_month, 1)

        with engine.connect() as conn:
            overall_stats = _get_overall_stats(conn, report_start, report_end)
            prev_stats = _get_overall_stats(conn, prev_start, prev_end)
            dept_breakdown = _get_department_breakdown(conn, report_start, report_end)
            daily_trends = _get_daily_trends(conn, report_start, report_end)
            peak_analysis = _get_peak_usage(conn, report_start, report_end)
            classroom_data = _get_classroom_consumption(conn, report_start, report_end)
            sensor_status = _get_sensor_status(conn, report_start, report_end)
            recommendations = _generate_recommendations(overall_stats, prev_stats, dept_breakdown, peak_analysis)
            insights = _generate_insights(overall_stats, daily_trends, dept_breakdown, peak_analysis)
            improvements = _generate_improvement_suggestions(overall_stats, peak_analysis, dept_breakdown)

            month_over_month_change = 0
            if prev_stats["total_energy"] > 0:
                month_over_month_change = (
                    (overall_stats["total_energy"] - prev_stats["total_energy"]) / prev_stats["total_energy"] * 100
                )

            report_period = {
                "month": target_month,
                "year": target_year,
                "month_name": report_start.strftime("%B"),
                "start_date": report_start.isoformat(),
                "end_date": report_end.isoformat(),
                "days_in_month": (report_end - report_start).days,
            }

            normal_report = _generate_normal_report(
                report_period,
                overall_stats,
                prev_stats,
                month_over_month_change,
                dept_breakdown,
                daily_trends,
                classroom_data,
                recommendations,
                insights,
                improvements,
                sensor_status,
            )
            technical_report = _generate_technical_report(
                report_period,
                overall_stats,
                prev_stats,
                month_over_month_change,
                dept_breakdown,
                daily_trends,
                peak_analysis,
                classroom_data,
                sensor_status,
                recommendations,
                insights,
                improvements,
            )

            legacy_department_breakdown = dept_breakdown
            legacy_daily_trends = daily_trends
            legacy_peak_analysis = peak_analysis
            legacy_classroom_consumption = classroom_data
            legacy_sensor_status = sensor_status
            legacy_recommendations = recommendations
            legacy_insights = insights.get("key_findings", [])
            legacy_improvements = improvements

            if report_type == "technical":
                legacy_department_breakdown = [
                    {
                        "department": item["department"],
                        "sensor_count": item["sensor_count"],
                        "readings": item["readings"],
                        "total_energy": item["energy_kwh"],
                        "avg_power": item["avg_power_w"],
                        "peak_power": item["peak_power_w"],
                    }
                    for item in technical_report["department_metrics"]
                ]
                legacy_daily_trends = [
                    {
                        "date": item["date"],
                        "daily_energy": item["daily_kwh"],
                        "avg_power": item["avg_power_w"],
                        "peak_power": item["peak_power_w"],
                        "readings": item["readings"],
                    }
                    for item in technical_report["daily_metrics"]
                ]
                legacy_peak_analysis = {
                    "top_peak_events": technical_report["top_peak_events"],
                    "hourly_pattern": technical_report["load_profile"],
                }
                legacy_classroom_consumption = [
                    {
                        "device_id": item["device_id"],
                        "readings": item["readings"],
                        "total_energy": item["energy_kwh"],
                        "avg_power": item["avg_power_w"],
                        "peak_power": item["peak_power_w"],
                        "first_reading": None,
                        "last_reading": None,
                    }
                    for item in technical_report["device_metrics"]
                ]
                legacy_sensor_status = {
                    "active_sensors": technical_report["quality_metrics"].get("active_sensors", 0),
                    "inactive_sensors": technical_report["quality_metrics"].get("inactive_sensors", 0),
                    "inactive_sensor_list": [],
                }
                legacy_recommendations = technical_report["technical_recommendations"]
                legacy_insights = technical_report["quality_metrics"].get("technical_findings", [])
                legacy_improvements = technical_report["optimization_actions"]

            response = {
                "success": True,
                "report_type": report_type,
                "report_period": report_period,
                "overall_statistics": overall_stats,
                "previous_month": prev_stats,
                "month_over_month_change": round(month_over_month_change, 2),
                "department_breakdown": legacy_department_breakdown,
                "daily_trends": legacy_daily_trends,
                "peak_usage_analysis": legacy_peak_analysis,
                "classroom_consumption": legacy_classroom_consumption,
                "sensor_status": legacy_sensor_status,
                "recommendations": legacy_recommendations,
                "insights": legacy_insights,
                "improvement_opportunities": legacy_improvements,
                "generated_at": datetime.now().isoformat(),
                "normal_report": normal_report,
                "technical_report": technical_report,
            }

            response["selected_report"] = normal_report if report_type != "technical" else technical_report
            return response

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error generating report: {str(e)}")


def _get_overall_stats(conn, start_date: datetime, end_date: datetime) -> Dict[str, Any]:
    """Calculate overall energy statistics for the period."""
    query = text("""
        SELECT 
            COUNT(DISTINCT device_id) as active_sensors,
            COUNT(*) as total_readings,
            COALESCE(SUM(energy), 0) as total_energy,
            COALESCE(AVG(power), 0) as avg_power,
            COALESCE(MAX(power), 0) as peak_power,
            COALESCE(AVG(voltage), 0) as avg_voltage,
            COALESCE(AVG(current), 0) as avg_current,
            COALESCE(AVG(power_factor), 0) as avg_power_factor
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
    """)
    
    result = conn.execute(query, {"start_date": start_date, "end_date": end_date}).fetchone()
    
    if result:
        return {
            "active_sensors": result[0] or 0,
            "total_readings": result[1] or 0,
            "total_energy": float(result[2] or 0),
            "avg_power": round(float(result[3] or 0), 2),
            "peak_power": round(float(result[4] or 0), 2),
            "avg_voltage": round(float(result[5] or 0), 2),
            "avg_current": round(float(result[6] or 0), 2),
            "avg_power_factor": round(float(result[7] or 0), 3),
        }
    
    return {
        "active_sensors": 0,
        "total_readings": 0,
        "total_energy": 0,
        "avg_power": 0,
        "peak_power": 0,
        "avg_voltage": 0,
        "avg_current": 0,
        "avg_power_factor": 0,
    }


def _get_department_breakdown(conn, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
    """Get energy consumption breakdown by department."""
    query = text("""
        SELECT 
            COALESCE(
                CASE 
                    WHEN device_id LIKE 'CS%' THEN 'Computer Science'
                    WHEN device_id LIKE 'EC%' THEN 'Electronics'
                    WHEN device_id LIKE 'EE%' THEN 'Electrical'
                    WHEN device_id LIKE 'ME%' THEN 'Mechanical'
                    WHEN device_id LIKE 'IT%' THEN 'Information Technology'
                    WHEN device_id LIKE 'ADMIN%' THEN 'Admin Block'
                    ELSE 'Other'
                END, 'Unknown'
            ) as department,
            COUNT(DISTINCT device_id) as sensor_count,
            COUNT(*) as readings,
            COALESCE(SUM(energy), 0) as total_energy,
            COALESCE(AVG(power), 0) as avg_power,
            COALESCE(MAX(power), 0) as peak_power
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
        GROUP BY department
        ORDER BY total_energy DESC
    """)
    
    results = conn.execute(query, {"start_date": start_date, "end_date": end_date}).fetchall()
    
    departments = []
    for row in results:
        departments.append({
            "department": row[0],
            "sensor_count": row[1] or 0,
            "readings": row[2] or 0,
            "total_energy": round(float(row[3] or 0), 2),
            "avg_power": round(float(row[4] or 0), 2),
            "peak_power": round(float(row[5] or 0), 2),
        })
    
    return departments


def _get_daily_trends(conn, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
    """Get daily energy consumption trends."""
    query = text("""
        SELECT 
            DATE(timestamp) as date,
            COALESCE(SUM(energy), 0) as daily_energy,
            COALESCE(AVG(power), 0) as avg_power,
            COALESCE(MAX(power), 0) as peak_power,
            COUNT(*) as readings
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
        GROUP BY DATE(timestamp)
        ORDER BY date
    """)
    
    results = conn.execute(query, {"start_date": start_date, "end_date": end_date}).fetchall()
    
    trends = []
    for row in results:
        trends.append({
            "date": row[0].isoformat() if row[0] else None,
            "daily_energy": round(float(row[1] or 0), 2),
            "avg_power": round(float(row[2] or 0), 2),
            "peak_power": round(float(row[3] or 0), 2),
            "readings": row[4] or 0,
        })
    
    return trends


def _get_peak_usage(conn, start_date: datetime, end_date: datetime) -> Dict[str, Any]:
    """Analyze peak usage patterns."""
    query = text("""
        SELECT 
            device_id,
            power,
            timestamp,
            voltage,
            current
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
        ORDER BY power DESC
        LIMIT 10
    """)
    
    results = conn.execute(query, {"start_date": start_date, "end_date": end_date}).fetchall()
    
    peak_events = []
    for row in results:
        peak_events.append({
            "device_id": row[0],
            "power": round(float(row[1] or 0), 2),
            "timestamp": row[2].isoformat() if row[2] else None,
            "voltage": round(float(row[3] or 0), 2),
            "current": round(float(row[4] or 0), 2),
        })
    
    # Hour of day analysis
    hourly_query = text("""
        SELECT 
            EXTRACT(HOUR FROM timestamp) as hour,
            COALESCE(AVG(power), 0) as avg_power,
            COUNT(*) as readings
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
        GROUP BY hour
        ORDER BY hour
    """)
    
    hourly_results = conn.execute(hourly_query, {"start_date": start_date, "end_date": end_date}).fetchall()
    
    hourly_pattern = []
    for row in hourly_results:
        hourly_pattern.append({
            "hour": int(row[0]),
            "avg_power": round(float(row[1] or 0), 2),
            "readings": row[2] or 0,
        })
    
    return {
        "top_peak_events": peak_events,
        "hourly_pattern": hourly_pattern,
    }


def _get_classroom_consumption(conn, start_date: datetime, end_date: datetime) -> List[Dict[str, Any]]:
    """Get consumption by classroom/device."""
    query = text("""
        SELECT 
            device_id,
            COUNT(*) as readings,
            COALESCE(SUM(energy), 0) as total_energy,
            COALESCE(AVG(power), 0) as avg_power,
            COALESCE(MAX(power), 0) as peak_power,
            MIN(timestamp) as first_reading,
            MAX(timestamp) as last_reading
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
        GROUP BY device_id
        ORDER BY total_energy DESC
        LIMIT 50
    """)
    
    results = conn.execute(query, {"start_date": start_date, "end_date": end_date}).fetchall()
    
    classrooms = []
    for row in results:
        classrooms.append({
            "device_id": row[0],
            "readings": row[1] or 0,
            "total_energy": round(float(row[2] or 0), 2),
            "avg_power": round(float(row[3] or 0), 2),
            "peak_power": round(float(row[4] or 0), 2),
            "first_reading": row[5].isoformat() if row[5] else None,
            "last_reading": row[6].isoformat() if row[6] else None,
        })
    
    return classrooms


def _get_sensor_status(conn, start_date: datetime, end_date: datetime) -> Dict[str, Any]:
    """Get sensor health and status information."""
    # Active sensors in the period
    active_query = text("""
        SELECT COUNT(DISTINCT device_id)
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
    """)
    
    active_count = conn.execute(active_query, {"start_date": start_date, "end_date": end_date}).scalar() or 0
    
    # Recently inactive sensors (last 7 days)
    inactive_query = text("""
        SELECT DISTINCT device_id
        FROM esp32_raw_data
        WHERE timestamp < :cutoff_date
        AND device_id NOT IN (
            SELECT DISTINCT device_id
            FROM esp32_raw_data
            WHERE timestamp >= :cutoff_date
        )
        LIMIT 20
    """)
    
    cutoff = end_date - timedelta(days=7)
    inactive_results = conn.execute(inactive_query, {"cutoff_date": cutoff}).fetchall()
    inactive_sensors = [row[0] for row in inactive_results]
    
    return {
        "active_sensors": active_count,
        "inactive_sensors": len(inactive_sensors),
        "inactive_sensor_list": inactive_sensors,
    }


def _generate_recommendations(
    overall: Dict, previous: Dict, departments: List[Dict], peak: Dict
) -> List[Dict[str, str]]:
    """Generate actionable recommendations based on data analysis."""
    recommendations = []
    
    # Energy consumption trend
    if previous['total_energy'] > 0:
        change = (overall['total_energy'] - previous['total_energy']) / previous['total_energy'] * 100
        if change > 10:
            recommendations.append({
                "priority": "high",
                "category": "Energy Consumption",
                "title": "Significant Increase in Energy Usage",
                "description": f"Energy consumption increased by {change:.1f}% compared to last month. "
                              f"Review high-consumption departments and implement energy-saving measures.",
                "action": "Conduct energy audit in top-consuming departments",
            })
        elif change < -10:
            recommendations.append({
                "priority": "low",
                "category": "Energy Consumption",
                "title": "Excellent Energy Savings Achieved",
                "description": f"Energy consumption decreased by {abs(change):.1f}% compared to last month. "
                              f"Continue current energy-saving practices.",
                "action": "Document and share best practices with other departments",
            })
    
    # Power factor analysis
    if overall['avg_power_factor'] < 0.85:
        recommendations.append({
            "priority": "medium",
            "category": "Power Quality",
            "title": "Low Power Factor Detected",
            "description": f"Average power factor is {overall['avg_power_factor']:.2f}, below optimal range (>0.85). "
                          f"This indicates inefficient power usage and may result in higher electricity bills.",
            "action": "Install power factor correction capacitors in affected areas",
        })
    
    # Department-specific recommendations
    if departments:
        highest_consumer = departments[0]
        if highest_consumer['total_energy'] > 0:
            recommendations.append({
                "priority": "medium",
                "category": "Department Focus",
                "title": f"High Consumption in {highest_consumer['department']}",
                "description": f"{highest_consumer['department']} consumed {highest_consumer['total_energy']:.1f} kWh "
                              f"with peak power of {highest_consumer['peak_power']:.1f}W. Consider targeted efficiency measures.",
                "action": f"Schedule energy audit for {highest_consumer['department']}",
            })
    
    # Peak usage recommendations
    if peak.get('hourly_pattern'):
        hourly = peak['hourly_pattern']
        peak_hours = sorted(hourly, key=lambda x: x['avg_power'], reverse=True)[:3]
        if peak_hours:
            peak_hour_list = ', '.join([f"{h['hour']}:00" for h in peak_hours])
            recommendations.append({
                "priority": "medium",
                "category": "Load Management",
                "title": "Peak Usage Hours Identified",
                "description": f"Highest consumption occurs during: {peak_hour_list}. "
                              f"Consider load shifting to off-peak hours to reduce demand charges.",
                "action": "Implement time-based equipment scheduling",
            })
    
    # Sensor health
    if overall['active_sensors'] < 10:
        recommendations.append({
            "priority": "high",
            "category": "System Maintenance",
            "title": "Low Sensor Count",
            "description": f"Only {overall['active_sensors']} sensors are actively reporting. "
                          f"This may indicate sensor failures or connectivity issues.",
            "action": "Inspect and repair inactive sensors",
        })
    
    # General best practices
    if overall['total_energy'] > 1000:
        recommendations.append({
            "priority": "low",
            "category": "Best Practices",
            "title": "Regular Maintenance Schedule",
            "description": "Maintain regular equipment servicing to ensure optimal energy efficiency. "
                          "Clean AC filters, check lighting systems, and verify HVAC settings.",
            "action": "Schedule monthly preventive maintenance checks",
        })
    
    if not recommendations:
        recommendations.append({
            "priority": "low",
            "category": "Status",
            "title": "All Systems Operating Normally",
            "description": "Energy consumption patterns are within expected ranges. "
                          "Continue monitoring and maintaining current practices.",
            "action": "Review report next month for trend analysis",
        })
    
    return recommendations


def _generate_insights(
    overall: Dict,
    daily_trends: List[Dict[str, Any]],
    departments: List[Dict[str, Any]],
    peak: Dict[str, Any],
) -> Dict[str, Any]:
    """Generate plain and technical observations from the measured data."""
    total_days = max(len(daily_trends), 1)
    avg_daily = overall["total_energy"] / total_days if total_days else 0
    top_department = departments[0]["department"] if departments else "Unknown"
    peak_hour = None
    if peak.get("hourly_pattern"):
        peak_hour = max(peak["hourly_pattern"], key=lambda item: item["avg_power"])

    return {
        "key_findings": [
            f"The facility consumed {overall['total_energy']:.2f} kWh during the report period.",
            f"Average daily usage was about {avg_daily:.2f} kWh across {total_days} tracked day(s).",
            f"{overall['active_sensors']} sensor node(s) were active and reporting data.",
            f"{top_department} was the highest consuming department in this period.",
        ],
        "technical_analysis": [
            f"Average voltage: {overall['avg_voltage']:.2f} V.",
            f"Average current: {overall['avg_current']:.3f} A.",
            f"Average power factor: {overall['avg_power_factor']:.3f}.",
            f"Peak demand: {overall['peak_power']:.2f} W.",
            f"Peak hour: {peak_hour['hour']:02d}:00" if peak_hour else "Peak hour: not available.",
        ],
        "usage_pattern": {
            "average_daily_energy": round(avg_daily, 2),
            "highest_department": top_department,
            "peak_hour": peak_hour["hour"] if peak_hour else None,
        },
    }


def _generate_improvement_suggestions(
    overall: Dict[str, Any],
    peak: Dict[str, Any],
    departments: List[Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Generate practical improvement actions based on the real readings."""
    suggestions: List[Dict[str, Any]] = []

    if overall["avg_power_factor"] < 0.85:
        suggestions.append({
            "priority": "high",
            "area": "Power quality",
            "suggestion": "Improve power factor with capacitor banks or power factor correction equipment.",
            "potential_impact": "Lower reactive loss and improve billing efficiency.",
        })

    if overall["peak_power"] > overall["avg_power"] * 1.8:
        suggestions.append({
            "priority": "high",
            "area": "Peak demand",
            "suggestion": "Shift non-critical loads away from peak hours to flatten the load curve.",
            "potential_impact": "Reduce demand spikes and improve operational stability.",
        })

    if departments:
        heavy = departments[0]
        suggestions.append({
            "priority": "medium",
            "area": heavy["department"],
            "suggestion": f"Review {heavy['department']} equipment usage and schedule a targeted efficiency audit.",
            "potential_impact": f"A reduction in the highest-consuming area could save {heavy['total_energy'] * 0.05:.2f} kWh.",
        })

    if peak.get("hourly_pattern"):
        busy_hours = sorted(peak["hourly_pattern"], key=lambda item: item["avg_power"], reverse=True)[:3]
        hour_text = ", ".join(f"{item['hour']:02d}:00" for item in busy_hours)
        suggestions.append({
            "priority": "medium",
            "area": "Scheduling",
            "suggestion": f"The highest average load was observed around {hour_text}. Move flexible equipment to quieter hours.",
            "potential_impact": "Less load overlap and smoother daily usage.",
        })

    suggestions.append({
        "priority": "low",
        "area": "Monitoring",
        "suggestion": "Keep collecting readings continuously so future comparisons stay accurate and evidence-based.",
        "potential_impact": "Better month-to-month planning and faster anomaly detection.",
    })

    return suggestions


def _generate_normal_report(
    report_period: Dict[str, Any],
    overall_stats: Dict[str, Any],
    prev_stats: Dict[str, Any],
    month_over_month_change: float,
    dept_breakdown: List[Dict[str, Any]],
    daily_trends: List[Dict[str, Any]],
    classroom_data: List[Dict[str, Any]],
    recommendations: List[Dict[str, Any]],
    insights: Dict[str, Any],
    improvements: List[Dict[str, Any]],
    sensor_status: Dict[str, Any],
) -> Dict[str, Any]:
    """Create a descriptive, easy-to-read report for normal users."""
    return {
        "report_kind": "normal",
        "title": f"Monthly Energy Report - {report_period['month_name']} {report_period['year']}",
        "summary": {
            "headline": f"The facility used {overall_stats['total_energy']:.2f} kWh this month.",
            "trend": f"Compared with last month, energy use {'increased' if month_over_month_change > 0 else 'decreased' if month_over_month_change < 0 else 'stayed the same'} by {abs(month_over_month_change):.2f}%.",
            "simple_status": "Good" if abs(month_over_month_change) <= 10 else "Needs attention",
        },
        "daily_story": {
            "description": "A simple day-by-day view of how energy was used.",
            "average_daily_energy": round(overall_stats['total_energy'] / max(len(daily_trends), 1), 2),
            "highest_day": max(daily_trends, key=lambda item: item['daily_energy'])['date'] if daily_trends else None,
            "lowest_day": min(daily_trends, key=lambda item: item['daily_energy'])['date'] if daily_trends else None,
        },
        "department_story": [
            {
                "name": item["department"],
                "description": f"{item['department']} consumed {item['total_energy']:.2f} kWh and had {item['sensor_count']} monitored area(s).",
                "share_of_total": round((item['total_energy'] / overall_stats['total_energy']) * 100, 2) if overall_stats['total_energy'] > 0 else 0,
            }
            for item in dept_breakdown
        ],
        "top_areas": [
            {
                "name": item["device_id"],
                "description": f"This area recorded {item['total_energy']:.2f} kWh in the period.",
            }
            for item in classroom_data[:10]
        ],
        "recommendations": [
            {
                "title": item["title"],
                "description": item["description"],
                "action": item["action"],
            }
            for item in recommendations[:6]
        ],
        "improvement_opportunities": improvements[:6],
        "insights": insights.get("key_findings", []),
        "sensor_note": f"{sensor_status.get('active_sensors', 0)} sensors were active during the period.",
        "closing_note": "All numbers in this report are based on real sensor readings from the monitoring system.",
    }


def _generate_technical_report(
    report_period: Dict[str, Any],
    overall_stats: Dict[str, Any],
    prev_stats: Dict[str, Any],
    month_over_month_change: float,
    dept_breakdown: List[Dict[str, Any]],
    daily_trends: List[Dict[str, Any]],
    peak_analysis: Dict[str, Any],
    classroom_data: List[Dict[str, Any]],
    sensor_status: Dict[str, Any],
    recommendations: List[Dict[str, Any]],
    insights: Dict[str, Any],
    improvements: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """Create a technical report with detailed power and usage metrics."""
    return {
        "report_kind": "technical",
        "title": f"Technical Energy Audit - {report_period['month_name']} {report_period['year']}",
        "system_summary": {
            "active_nodes": overall_stats["active_sensors"],
            "reading_count": overall_stats["total_readings"],
            "total_kwh": round(overall_stats["total_energy"], 3),
            "avg_kw": round(overall_stats["avg_power"] / 1000, 4),
            "peak_w": round(overall_stats["peak_power"], 2),
            "avg_v": round(overall_stats["avg_voltage"], 2),
            "avg_a": round(overall_stats["avg_current"], 3),
            "pf": round(overall_stats["avg_power_factor"], 3),
            "mom_change_percent": round(month_over_month_change, 2),
        },
        "comparison": {
            "previous_month_kwh": round(prev_stats["total_energy"], 3),
            "delta_kwh": round(overall_stats["total_energy"] - prev_stats["total_energy"], 3),
            "delta_percent": round(month_over_month_change, 2),
        },
        "department_metrics": [
            {
                "department": item["department"],
                "sensor_count": item["sensor_count"],
                "readings": item["readings"],
                "energy_kwh": round(item["total_energy"], 3),
                "avg_power_w": round(item["avg_power"], 2),
                "peak_power_w": round(item["peak_power"], 2),
                "energy_share_percent": round((item["total_energy"] / overall_stats["total_energy"] * 100), 2) if overall_stats["total_energy"] > 0 else 0,
            }
            for item in dept_breakdown
        ],
        "daily_metrics": [
            {
                "date": item["date"],
                "daily_kwh": round(item["daily_energy"], 3),
                "avg_power_w": round(item["avg_power"], 2),
                "peak_power_w": round(item["peak_power"], 2),
                "readings": item["readings"],
            }
            for item in daily_trends
        ],
        "load_profile": peak_analysis.get("hourly_pattern", []),
        "top_peak_events": peak_analysis.get("top_peak_events", [])[:12],
        "device_metrics": [
            {
                "device_id": item["device_id"],
                "readings": item["readings"],
                "energy_kwh": round(item["total_energy"], 3),
                "avg_power_w": round(item["avg_power"], 2),
                "peak_power_w": round(item["peak_power"], 2),
            }
            for item in classroom_data[:20]
        ],
        "quality_metrics": {
            "active_sensors": sensor_status.get("active_sensors", 0),
            "inactive_sensors": sensor_status.get("inactive_sensors", 0),
            "technical_findings": insights.get("technical_analysis", []),
        },
        "technical_recommendations": recommendations[:6],
        "optimization_actions": improvements[:6],
    }


@router.get("/monthly-report/summary")
async def get_report_summary(month: int = None, year: int = None, authorization: str | None = Header(default=None, alias="Authorization")):
    """Get a quick summary of the monthly report (for preview)."""
    try:
        _verify_admin_token(authorization)

        now = datetime.now()
        target_month = month or now.month
        target_year = year or now.year
        
        report_start = datetime(target_year, target_month, 1)
        if target_month == 12:
            report_end = datetime(target_year + 1, 1, 1)
        else:
            report_end = datetime(target_year, target_month + 1, 1)
        
        with engine.connect() as conn:
            overall_stats = _get_overall_stats(conn, report_start, report_end)
            
            return {
                "success": True,
                "period": f"{report_start.strftime('%B %Y')}",
                "total_energy": overall_stats['total_energy'],
                "active_sensors": overall_stats['active_sensors'],
                "total_readings": overall_stats['total_readings'],
            }
    
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error generating summary: {str(e)}")


app.include_router(router)
