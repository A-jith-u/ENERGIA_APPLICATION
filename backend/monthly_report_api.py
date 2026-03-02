"""Monthly Report API for Energia System.
Generates comprehensive monthly reports with energy consumption analytics,
trends, recommendations, and department-wise breakdowns.
"""
from fastapi import APIRouter, HTTPException
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text, func
from typing import Dict, List, Any
import json
from decimal import Decimal

from .config import get_db_url
from fastapi import FastAPI

app = FastAPI() # Make sure this line exists!
router = APIRouter()
engine = create_engine(get_db_url())


def _decimal_default(obj):
    """JSON serializer for Decimal objects."""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError


@router.get("/monthly-report")
async def get_monthly_report(month: int = None, year: int = None):
    """Generate comprehensive monthly report.
    
    Args:
        month: Month number (1-12). Defaults to current month.
        year: Year (e.g., 2026). Defaults to current year.
    
    Returns:
        Complete monthly report with:
        - Overall statistics
        - Department-wise breakdown
        - Daily consumption trends
        - Peak usage analysis
        - Recommendations for improvement
        - Comparative analysis with previous month
    """
    try:
        # Default to current month if not specified
        now = datetime.now()
        target_month = month or now.month
        target_year = year or now.year
        
        # Calculate date ranges
        report_start = datetime(target_year, target_month, 1)
        if target_month == 12:
            report_end = datetime(target_year + 1, 1, 1)
        else:
            report_end = datetime(target_year, target_month + 1, 1)
        
        # Previous month for comparison
        if target_month == 1:
            prev_start = datetime(target_year - 1, 12, 1)
            prev_end = datetime(target_year, 1, 1)
        else:
            prev_start = datetime(target_year, target_month - 1, 1)
            prev_end = datetime(target_year, target_month, 1)
        
        with engine.connect() as conn:
            # 1. Overall Statistics
            overall_stats = _get_overall_stats(conn, report_start, report_end)
            
            # 2. Previous month stats for comparison
            prev_stats = _get_overall_stats(conn, prev_start, prev_end)
            
            # 3. Department-wise breakdown
            dept_breakdown = _get_department_breakdown(conn, report_start, report_end)
            
            # 4. Daily consumption trends
            daily_trends = _get_daily_trends(conn, report_start, report_end)
            
            # 5. Peak usage analysis
            peak_analysis = _get_peak_usage(conn, report_start, report_end)
            
            # 6. Classroom-wise consumption
            classroom_data = _get_classroom_consumption(conn, report_start, report_end)
            
            # 7. Generate recommendations
            recommendations = _generate_recommendations(
                overall_stats, prev_stats, dept_breakdown, peak_analysis
            )
            
            # 8. Active sensors status
            sensor_status = _get_sensor_status(conn, report_start, report_end)
            
            # Calculate percentage changes
            month_over_month_change = 0
            if prev_stats['total_energy'] > 0:
                month_over_month_change = (
                    (overall_stats['total_energy'] - prev_stats['total_energy']) 
                    / prev_stats['total_energy'] * 100
                )
            
            return {
                "success": True,
                "report_period": {
                    "month": target_month,
                    "year": target_year,
                    "month_name": report_start.strftime("%B"),
                    "start_date": report_start.isoformat(),
                    "end_date": report_end.isoformat(),
                    "days_in_month": (report_end - report_start).days,
                },
                "overall_statistics": overall_stats,
                "previous_month": prev_stats,
                "month_over_month_change": round(month_over_month_change, 2),
                "department_breakdown": dept_breakdown,
                "daily_trends": daily_trends,
                "peak_usage_analysis": peak_analysis,
                "classroom_consumption": classroom_data,
                "sensor_status": sensor_status,
                "recommendations": recommendations,
                "generated_at": datetime.now().isoformat(),
            }
    
    except Exception as e:
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


@router.get("/monthly-report/summary")
async def get_report_summary(month: int = None, year: int = None):
    """Get a quick summary of the monthly report (for preview)."""
    try:
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
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating summary: {str(e)}")
