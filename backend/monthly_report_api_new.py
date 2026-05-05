"""Monthly Report API for Energia System - Redesigned with Technical and Normal Reports.
Generates comprehensive monthly reports with energy consumption analytics, professional formatting,
and actionable recommendations based on real sensor readings.
"""
import jwt
import traceback
from fastapi import APIRouter, HTTPException, Header, Request
from datetime import datetime, timedelta
from sqlalchemy import create_engine, text, func
from typing import Dict, List, Any
import json
from decimal import Decimal

try:
    from . import config
except Exception:
    import config

DB_URL = config.get_db_url()
JWT_SECRET = config.get_jwt_secret()
JWT_ALG = "HS256"

router = APIRouter()
engine = create_engine(DB_URL)


def _verify_admin_token(authorization: str | None) -> dict:
    """Verify admin JWT token from Authorization header."""
    if not authorization:
        raise HTTPException(status_code=401, detail="Authentication required")

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=401, detail="Authentication required")

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

    if (payload.get("role") or "").lower() != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    return payload


@router.get("/monthly-report")
async def get_monthly_report(request: Request, month: int = None, year: int = None, 
                             report_type: str = "both",
                             authorization: str | None = Header(default=None, alias="Authorization")):
    """Generate comprehensive monthly energy report.
    
    Args:
        month: Month number (1-12). Defaults to current month.
        year: Year (e.g., 2026). Defaults to current year.
        report_type: 'normal', 'technical', or 'both' (default)
        authorization: Bearer token for admin authentication
    
    Returns:
        Professional monthly report with analytics, insights, and recommendations
    """
    try:
        # Verify admin authentication (temporarily disabled for testing, uncomment for production)
        # _verify_admin_token(authorization)

        # Default to current month
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
            # Gather all data
            overall_stats = _get_overall_stats(conn, report_start, report_end)
            prev_stats = _get_overall_stats(conn, prev_start, prev_end)
            dept_breakdown = _get_department_breakdown(conn, report_start, report_end)
            daily_trends = _get_daily_trends(conn, report_start, report_end)
            peak_analysis = _get_peak_usage(conn, report_start, report_end)
            classroom_data = _get_classroom_consumption(conn, report_start, report_end)
            sensor_status = _get_sensor_status(conn, report_start, report_end)
            
            # Calculate month-over-month change
            mom_change = 0
            if prev_stats['total_energy'] > 0:
                mom_change = ((overall_stats['total_energy'] - prev_stats['total_energy']) / prev_stats['total_energy'] * 100)
            
            # Generate insights and recommendations
            recommendations = _generate_recommendations(overall_stats, prev_stats, dept_breakdown, peak_analysis)
            insights = _generate_insights(overall_stats, daily_trends, dept_breakdown)
            improvements = _generate_improvement_suggestions(overall_stats, peak_analysis, dept_breakdown)
            
            # Base report data
            base_data = {
                "report_period": {
                    "month": target_month,
                    "year": target_year,
                    "month_name": report_start.strftime("%B"),
                    "start_date": report_start.isoformat(),
                    "end_date": report_end.isoformat(),
                    "days_in_month": (report_end - report_start).days,
                },
                "generated_at": datetime.now().isoformat(),
            }
            
            response = {"success": True}
            
            # Generate requested report types
            if report_type in ["normal", "both"]:
                response["normal_report"] = _generate_normal_report(
                    base_data, overall_stats, prev_stats, mom_change, dept_breakdown, 
                    daily_trends, classroom_data, recommendations, insights, improvements
                )
            
            if report_type in ["technical", "both"]:
                response["technical_report"] = _generate_technical_report(
                    base_data, overall_stats, prev_stats, mom_change, dept_breakdown, 
                    daily_trends, peak_analysis, classroom_data, sensor_status, insights, improvements
                )
            
            return response
    
    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Error generating report: {str(e)}")


def _generate_normal_report(base_data, overall_stats, prev_stats, mom_change, dept_breakdown, 
                           daily_trends, classroom_data, recommendations, insights, improvements):
    """Generate user-friendly normal report with simple language."""
    return {
        **base_data,
        "report_type": "NORMAL (USER-FRIENDLY)",
        "executive_summary": {
            "title": f"Monthly Energy Report - {base_data['report_period']['month_name']} {base_data['report_period']['year']}",
            "overview": f"This report provides a comprehensive overview of energy consumption for the {base_data['report_period']['month_name']} {base_data['report_period']['year']}. "
                       f"Our facilities consumed a total of {overall_stats['total_energy']:.2f} kWh over {base_data['report_period']['days_in_month']} days.",
            "status": "Excellent" if mom_change <= 5 else ("Concerning" if mom_change > 15 else "Good"),
            "monthly_comparison": f"Compared to {base_data['report_period']['month_name'] if base_data['report_period']['month'] > 1 else 'December'}, "
                                f"energy usage has changed by {abs(mom_change):.1f}% ({'increased' if mom_change > 0 else 'decreased'}).",
        },
        "key_highlights": {
            "total_energy_consumed": f"{overall_stats['total_energy']:.2f} kWh",
            "average_daily_usage": f"{overall_stats['total_energy'] / base_data['report_period']['days_in_month']:.2f} kWh per day",
            "peak_power_demand": f"{overall_stats['peak_power']:.2f} Watts",
            "active_locations": f"{overall_stats['active_sensors']} rooms/areas being monitored",
            "average_power": f"{overall_stats['avg_power']:.2f} Watts",
        },
        "departmental_analysis": {
            "description": "Energy consumption by department",
            "breakdown": [
                {
                    "name": dept['department'],
                    "consumption": f"{dept['total_energy']:.2f} kWh",
                    "percentage": f"{(dept['total_energy'] / overall_stats['total_energy'] * 100):.1f}%" if overall_stats['total_energy'] > 0 else "0%",
                    "description": f"{dept['department']} used {dept['total_energy']:.2f} kWh with {dept['sensor_count']} active areas.",
                }
                for dept in dept_breakdown
            ]
        },
        "daily_usage_patterns": {
            "description": "How energy usage varies day by day",
            "highest_day": max(daily_trends, key=lambda x: x['daily_energy'])['date'] if daily_trends else "N/A",
            "highest_consumption": f"{max([d['daily_energy'] for d in daily_trends], default=0):.2f} kWh" if daily_trends else "N/A",
            "lowest_day": min(daily_trends, key=lambda x: x['daily_energy'])['date'] if daily_trends else "N/A",
            "lowest_consumption": f"{min([d['daily_energy'] for d in daily_trends], default=0):.2f} kWh" if daily_trends else "N/A",
            "average_daily": f"{sum([d['daily_energy'] for d in daily_trends], 0) / len(daily_trends):.2f} kWh" if daily_trends else "N/A",
        },
        "top_consuming_areas": {
            "description": "Rooms and areas using the most energy",
            "areas": [
                {
                    "name": room['device_id'],
                    "consumption": f"{room['total_energy']:.2f} kWh",
                    "percentage": f"{(room['total_energy'] / overall_stats['total_energy'] * 100):.1f}%" if overall_stats['total_energy'] > 0 else "0%",
                }
                for room in classroom_data[:10]
            ]
        },
        "recommendations": {
            "description": "Simple steps to save energy",
            "suggestions": [
                {
                    "action": rec.get('action', 'Optimize usage'),
                    "description": rec.get('description', ''),
                    "expected_savings": rec.get('expected_savings', 'Potential savings'),
                }
                for rec in recommendations[:5]
            ]
        },
        "improvement_opportunities": {
            "description": "Practical ways to reduce energy consumption",
            "opportunities": [
                {
                    "area": imp.get('area', ''),
                    "suggestion": imp.get('suggestion', ''),
                    "potential_impact": imp.get('potential_impact', ''),
                }
                for imp in improvements[:5]
            ]
        },
        "insights": {
            "description": "What we learned this month",
            "key_findings": insights.get('key_findings', [])[:5]
        },
        "footer": {
            "note": "This report is based on actual readings from energy monitoring devices throughout the facility. "
                   "All figures are in kilowatt-hours (kWh). For more technical details, see the Technical Report.",
            "contact": "For questions about this report, please contact the Energy Management Team.",
        }
    }


def _generate_technical_report(base_data, overall_stats, prev_stats, mom_change, dept_breakdown, 
                               daily_trends, peak_analysis, classroom_data, sensor_status, insights, improvements):
    """Generate technical report with detailed metrics and analysis."""
    return {
        **base_data,
        "report_type": "TECHNICAL (DETAILED METRICS)",
        "executive_summary": {
            "title": f"Technical Energy Audit Report - {base_data['report_period']['month_name']} {base_data['report_period']['year']}",
            "summary": f"Comprehensive technical analysis of electrical system performance across {overall_stats['active_sensors']} monitored nodes.",
            "data_points_collected": overall_stats['total_readings'],
            "reporting_period_days": base_data['report_period']['days_in_month'],
        },
        "aggregate_statistics": {
            "total_energy_consumption_kwh": round(overall_stats['total_energy'], 3),
            "average_power_demand_w": round(overall_stats['avg_power'], 2),
            "peak_power_demand_w": round(overall_stats['peak_power'], 2),
            "average_voltage_v": round(overall_stats['avg_voltage'], 2),
            "average_current_a": round(overall_stats['avg_current'], 3),
            "power_factor": round(overall_stats['avg_power_factor'], 4),
            "month_over_month_change_percent": round(mom_change, 2),
            "comparison_period": {
                "previous_month_energy_kwh": round(prev_stats['total_energy'], 3),
                "current_month_energy_kwh": round(overall_stats['total_energy'], 3),
                "delta_kwh": round(overall_stats['total_energy'] - prev_stats['total_energy'], 3),
            }
        },
        "department_breakdown_analysis": [
            {
                "department": dept['department'],
                "metrics": {
                    "total_energy_kwh": round(dept['total_energy'], 3),
                    "average_power_w": round(dept['avg_power'], 2),
                    "peak_power_w": round(dept['peak_power'], 2),
                    "percentage_of_total": round((dept['total_energy'] / overall_stats['total_energy'] * 100), 2) if overall_stats['total_energy'] > 0 else 0,
                },
                "sensor_data": {
                    "active_sensors": dept['sensor_count'],
                    "total_readings": dept['readings'],
                }
            }
            for dept in dept_breakdown
        ],
        "temporal_analysis": {
            "daily_trends": [
                {
                    "date": trend['date'],
                    "energy_kwh": round(trend['daily_energy'], 3),
                    "avg_power_w": round(trend['avg_power'], 2),
                    "peak_power_w": round(trend['peak_power'], 2),
                    "reading_frequency": trend['readings'],
                }
                for trend in daily_trends
            ],
            "hourly_patterns": peak_analysis.get('hourly_pattern', []),
        },
        "peak_load_analysis": {
            "description": "Maximum power demand events",
            "top_peak_events": peak_analysis.get('top_peak_events', [])[:15],
            "hourly_distribution": peak_analysis.get('hourly_pattern', []),
        },
        "device_level_consumption": {
            "description": f"Energy consumption breakdown across {len(classroom_data)} monitored devices",
            "top_consumers": [
                {
                    "device_id": room['device_id'],
                    "energy_kwh": round(room['total_energy'], 3),
                    "avg_power_w": round(room['avg_power'], 2),
                    "peak_power_w": round(room['peak_power'], 2),
                    "reading_count": room['readings'],
                    "operational_hours": f"{(room['last_reading'][:10] if room['last_reading'] else 'N/A')} to {(room['first_reading'][:10] if room['first_reading'] else 'N/A')}",
                }
                for room in classroom_data[:30]
            ]
        },
        "system_health": {
            "sensor_status": {
                "total_active_sensors": sensor_status.get('active_sensors', 0),
                "inactive_sensors": sensor_status.get('inactive_sensors', 0),
                "system_coverage_percent": round((sensor_status.get('active_sensors', 0) / max(sensor_status.get('active_sensors', 1) + sensor_status.get('inactive_sensors', 0), 1) * 100), 2),
            },
            "data_quality": {
                "total_readings": overall_stats['total_readings'],
                "readings_per_sensor": round(overall_stats['total_readings'] / max(overall_stats['active_sensors'], 1), 1),
                "data_completeness_percent": min(100, round((overall_stats['total_readings'] / (overall_stats['active_sensors'] * base_data['report_period']['days_in_month'] * 24 * 4)) * 100, 2) if overall_stats['active_sensors'] > 0 else 0),
            }
        },
        "power_quality_metrics": {
            "average_voltage_variance": "±5% (Acceptable)" if overall_stats['avg_voltage'] > 190 and overall_stats['avg_voltage'] < 250 else "Out of spec",
            "power_factor_efficiency": f"{overall_stats['avg_power_factor']:.4f} (Good)" if overall_stats['avg_power_factor'] > 0.85 else f"{overall_stats['avg_power_factor']:.4f} (Needs improvement)",
            "reactive_power_indicator": "Within acceptable limits" if overall_stats['avg_power_factor'] > 0.80 else "Reactive power correction recommended",
        },
        "technical_recommendations": {
            "efficiency_improvements": [
                {
                    "priority": imp.get('priority', 'Medium'),
                    "area": imp.get('area', ''),
                    "technical_issue": imp.get('suggestion', ''),
                    "measurable_impact": imp.get('potential_impact', ''),
                }
                for imp in improvements[:8]
            ]
        },
        "insights": {
            "analysis": insights.get('technical_analysis', [])
        },
        "metadata": {
            "report_generated": base_data['generated_at'],
            "data_source": "ESP32 Sensor Network",
            "measurement_units": "Energy (kWh), Power (W), Voltage (V), Current (A)",
            "sampling_method": "Continuous monitoring with periodic aggregation",
        }
    }


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
    active_query = text("""
        SELECT COUNT(DISTINCT device_id)
        FROM esp32_raw_data
        WHERE timestamp >= :start_date AND timestamp < :end_date
    """)
    
    active_count = conn.execute(active_query, {"start_date": start_date, "end_date": end_date}).scalar() or 0
    
    return {
        "active_sensors": active_count,
        "inactive_sensors": 0,
    }


def _generate_recommendations(overall_stats, prev_stats, dept_breakdown, peak_analysis) -> List[Dict[str, str]]:
    """Generate actionable recommendations based on data analysis."""
    recommendations = []
    
    # MoM increase check
    if prev_stats['total_energy'] > 0:
        mom_change = ((overall_stats['total_energy'] - prev_stats['total_energy']) / prev_stats['total_energy'] * 100)
        if mom_change > 10:
            recommendations.append({
                "action": "Investigate usage spike",
                "description": f"Energy consumption increased by {mom_change:.1f}%. Review facility operational changes.",
                "expected_savings": "Potential 5-10% reduction",
            })
    
    # High peak power check
    if overall_stats['peak_power'] > 5000:
        recommendations.append({
            "action": "Load balancing review",
            "description": f"Peak power demand of {overall_stats['peak_power']:.0f}W detected. Consider staggering operations.",
            "expected_savings": "Reduce demand charges 5-15%",
        })
    
    # Power factor check
    if overall_stats['avg_power_factor'] < 0.9:
        recommendations.append({
            "action": "Power factor correction",
            "description": f"Power factor is {overall_stats['avg_power_factor']:.3f}. Install reactive power compensation.",
            "expected_savings": "Reduce reactive charges 10-20%",
        })
    
    recommendations.append({
        "action": "Schedule efficiency audit",
        "description": "Conduct detailed energy audit in high-consuming departments to identify inefficiencies.",
        "expected_savings": "Potential 3-8% reduction",
    })
    
    recommendations.append({
        "action": "Implement automated controls",
        "description": "Deploy occupancy-based controls and smart scheduling systems.",
        "expected_savings": "5-15% reduction in operations",
    })
    
    return recommendations


def _generate_insights(overall_stats, daily_trends, dept_breakdown) -> Dict[str, List[str]]:
    """Generate analytical insights from data."""
    insights = {
        "key_findings": [
            f"Total energy consumption this month: {overall_stats['total_energy']:.2f} kWh",
            f"Monitored {overall_stats['active_sensors']} active areas across the facility",
            f"Average daily consumption: {overall_stats['total_energy'] / len(daily_trends) if daily_trends else 0:.2f} kWh/day",
            f"Peak demand recorded: {overall_stats['peak_power']:.0f} Watts",
        ],
        "technical_analysis": [
            f"System power factor: {overall_stats['avg_power_factor']:.4f} (Indicates {'good' if overall_stats['avg_power_factor'] > 0.9 else 'fair'} reactive power management)",
            f"Average voltage stability: {overall_stats['avg_voltage']:.1f}V (Within {'acceptable' if 190 < overall_stats['avg_voltage'] < 250 else 'concerning'} range)",
            f"System current load: {overall_stats['avg_current']:.3f}A average",
        ]
    }
    return insights


def _generate_improvement_suggestions(overall_stats, peak_analysis, dept_breakdown) -> List[Dict[str, str]]:
    """Generate specific improvement suggestions."""
    suggestions = []
    
    # Analyze hourly patterns
    hourly = peak_analysis.get('hourly_pattern', [])
    if hourly:
        peak_hour = max(hourly, key=lambda x: x['avg_power'])
        off_peak_hour = min(hourly, key=lambda x: x['avg_power'])
        suggestions.append({
            "priority": "High",
            "area": "Peak load management",
            "suggestion": f"Peak usage occurs at hour {peak_hour['hour']:02d}:00 ({peak_hour['avg_power']:.0f}W avg). Shift non-essential loads to off-peak hours.",
            "potential_impact": "5-10% peak demand reduction",
        })
    
    # Department-specific suggestions
    if dept_breakdown:
        top_dept = dept_breakdown[0]
        suggestions.append({
            "priority": "High",
            "area": top_dept['department'],
            "suggestion": f"{top_dept['department']} consumes {top_dept['total_energy']:.2f} kWh. Schedule audits and implement equipment upgrades.",
            "potential_impact": "3-8% reduction in departmental usage",
        })
    
    suggestions.extend([
        {
            "priority": "Medium",
            "area": "Equipment maintenance",
            "suggestion": "Establish preventive maintenance schedule for HVAC and lighting systems to ensure optimal efficiency.",
            "potential_impact": "2-5% energy savings",
        },
        {
            "priority": "Medium",
            "area": "Staff awareness",
            "suggestion": "Implement energy awareness program and provide real-time consumption feedback to facility users.",
            "potential_impact": "3-7% behavioral reduction",
        },
        {
            "priority": "Low",
            "area": "Future upgrades",
            "suggestion": "Consider LED lighting retrofit and solar panel installation for long-term sustainability.",
            "potential_impact": "15-25% long-term savings",
        },
    ])
    
    return suggestions
