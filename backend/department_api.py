"""
Department Customization API
Handles department-specific configurations, user assignments, and UI customizations.
"""
from flask import Blueprint, request, jsonify
from flask_cors import cross_origin
from sqlalchemy import create_engine, select, text, MetaData, Table, insert, update, delete
from datetime import datetime
import json
import logging

# Initialize Blueprint
dept_api = Blueprint('dept_api', __name__, url_prefix='/api/department')

logger = logging.getLogger(__name__)

# This will be initialized by the main app
engine = None
metadata = None


def init_department_api(app, db_engine, db_metadata):
    """Initialize the department API with database connections."""
    global engine, metadata
    engine = db_engine
    metadata = db_metadata
    app.register_blueprint(dept_api)


# ============================================================================
# Department Management Endpoints
# ============================================================================

@dept_api.route('/list', methods=['GET'])
@cross_origin()
def list_departments():
    """Get all departments with their customization settings."""
    try:
        with engine.begin() as conn:
            customization_table = Table('department_customization', metadata, autoload_with=engine)
            result = conn.execute(select(customization_table)).fetchall()

            departments = []
            for row in result:
                departments.append({
                    'id': row.id,
                    'department': row.department,
                    'display_name': row.display_name,
                    'color_hex': row.color_hex,
                    'icon_name': row.icon_name,
                    'enabled_features': json.loads(row.enabled_features) if row.enabled_features else [],
                    'metrics_to_display': json.loads(row.metrics_to_display) if row.metrics_to_display else [],
                })

            return jsonify({'success': True, 'departments': departments}), 200

    except Exception as e:
        logger.error(f"Error listing departments: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/get/<department>', methods=['GET'])
@cross_origin()
def get_department_config(department):
    """Get customization config for a specific department."""
    try:
        with engine.begin() as conn:
            customization_table = Table('department_customization', metadata, autoload_with=engine)
            result = conn.execute(
                select(customization_table).where(customization_table.c.department == department)
            ).fetchone()

            if not result:
                return jsonify({'success': False, 'error': 'Department not found'}), 404

            config = {
                'id': result.id,
                'department': result.department,
                'display_name': result.display_name,
                'color_hex': result.color_hex,
                'icon_name': result.icon_name,
                'enabled_features': json.loads(result.enabled_features) if result.enabled_features else [],
                'dashboard_layout': json.loads(result.dashboard_layout) if result.dashboard_layout else {},
                'metrics_to_display': json.loads(result.metrics_to_display) if result.metrics_to_display else [],
                'custom_rooms': json.loads(result.custom_rooms) if result.custom_rooms else [],
                'created_at': result.created_at.isoformat() if result.created_at else None,
                'updated_at': result.updated_at.isoformat() if result.updated_at else None,
            }

            return jsonify({'success': True, 'config': config}), 200

    except Exception as e:
        logger.error(f"Error getting department config: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/create', methods=['POST'])
@cross_origin()
def create_department_config():
    """Create a new department customization configuration."""
    try:
        data = request.get_json()

        required_fields = ['department', 'display_name', 'color_hex', 'icon_name']
        if not all(field in data for field in required_fields):
            return jsonify({'success': False, 'error': 'Missing required fields'}), 400

        with engine.begin() as conn:
            customization_table = Table('department_customization', metadata, autoload_with=engine)

            # Check if department already exists
            existing = conn.execute(
                select(customization_table).where(customization_table.c.department == data['department'])
            ).fetchone()

            if existing:
                return jsonify({'success': False, 'error': 'Department already exists'}), 409

            conn.execute(customization_table.insert().values(
                department=data['department'],
                display_name=data['display_name'],
                color_hex=data['color_hex'],
                icon_name=data['icon_name'],
                enabled_features=json.dumps(data.get('enabled_features', [])),
                dashboard_layout=json.dumps(data.get('dashboard_layout', {})),
                metrics_to_display=json.dumps(data.get('metrics_to_display', [])),
                custom_rooms=json.dumps(data.get('custom_rooms', [])),
                created_at=datetime.now(),
                updated_at=datetime.now(),
            ))

            return jsonify({
                'success': True,
                'message': 'Department configuration created successfully',
                'department': data['department']
            }), 201

    except Exception as e:
        logger.error(f"Error creating department config: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/update/<department>', methods=['PUT'])
@cross_origin()
def update_department_config(department):
    """Update department customization configuration."""
    try:
        data = request.get_json()

        with engine.begin() as conn:
            customization_table = Table('department_customization', metadata, autoload_with=engine)

            # Check if department exists
            existing = conn.execute(
                select(customization_table).where(customization_table.c.department == department)
            ).fetchone()

            if not existing:
                return jsonify({'success': False, 'error': 'Department not found'}), 404

            # Build update dict
            update_data = {}
            if 'display_name' in data:
                update_data['display_name'] = data['display_name']
            if 'color_hex' in data:
                update_data['color_hex'] = data['color_hex']
            if 'icon_name' in data:
                update_data['icon_name'] = data['icon_name']
            if 'enabled_features' in data:
                update_data['enabled_features'] = json.dumps(data['enabled_features'])
            if 'dashboard_layout' in data:
                update_data['dashboard_layout'] = json.dumps(data['dashboard_layout'])
            if 'metrics_to_display' in data:
                update_data['metrics_to_display'] = json.dumps(data['metrics_to_display'])
            if 'custom_rooms' in data:
                update_data['custom_rooms'] = json.dumps(data['custom_rooms'])

            update_data['updated_at'] = datetime.now()

            conn.execute(
                customization_table.update()
                .where(customization_table.c.department == department)
                .values(**update_data)
            )

            return jsonify({
                'success': True,
                'message': 'Department configuration updated successfully'
            }), 200

    except Exception as e:
        logger.error(f"Error updating department config: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# User Department Assignment Endpoints
# ============================================================================

@dept_api.route('/coordinator/<coordinator_id>/assign-rooms', methods=['POST'])
@cross_origin()
def assign_rooms_to_coordinator(coordinator_id):
    """Assign rooms to a technical coordinator."""
    try:
        data = request.get_json()
        room_ids = data.get('room_ids', [])

        with engine.begin() as conn:
            coordinators_table = Table('coordinators', metadata, autoload_with=engine)

            # Update coordinator's assigned rooms
            conn.execute(
                coordinators_table.update()
                .where(coordinators_table.c.coordinator_id == coordinator_id)
                .values(assigned_rooms=json.dumps(room_ids))
            )

            return jsonify({
                'success': True,
                'message': 'Rooms assigned to coordinator successfully'
            }), 200

    except Exception as e:
        logger.error(f"Error assigning rooms to coordinator: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/class-rep/<username>/assign-rooms', methods=['POST'])
@cross_origin()
def assign_rooms_to_class_rep(username):
    """Assign classrooms to a class representative."""
    try:
        data = request.get_json()
        room_ids = data.get('room_ids', [])

        with engine.begin() as conn:
            class_reps_table = Table('class_representatives', metadata, autoload_with=engine)

            # Update class rep's assigned rooms
            conn.execute(
                class_reps_table.update()
                .where(class_reps_table.c.username == username)
                .values(assigned_rooms=json.dumps(room_ids))
            )

            return jsonify({
                'success': True,
                'message': 'Rooms assigned to class representative successfully'
            }), 200

    except Exception as e:
        logger.error(f"Error assigning rooms to class rep: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/get-coordinator-rooms/<coordinator_id>', methods=['GET'])
@cross_origin()
def get_coordinator_rooms(coordinator_id):
    """Get rooms assigned to a coordinator."""
    try:
        with engine.begin() as conn:
            coordinators_table = Table('coordinators', metadata, autoload_with=engine)
            rooms_table = Table('rooms', metadata, autoload_with=engine)

            # Get coordinator
            coordinator = conn.execute(
                select(coordinators_table).where(coordinators_table.c.coordinator_id == coordinator_id)
            ).fetchone()

            if not coordinator:
                return jsonify({'success': False, 'error': 'Coordinator not found'}), 404

            assigned_rooms = json.loads(coordinator.assigned_rooms) if coordinator.assigned_rooms else []

            # Get room details
            if assigned_rooms:
                rooms = conn.execute(
                    select(rooms_table).where(rooms_table.c.room_id.in_(assigned_rooms))
                ).fetchall()

                room_list = [{
                    'id': room.id,
                    'room_id': room.room_id,
                    'room_name': room.room_name,
                    'floor_number': room.floor_number,
                    'department': room.department,
                    'threshold': room.threshold,
                } for room in rooms]
            else:
                room_list = []

            return jsonify({
                'success': True,
                'coordinator_id': coordinator_id,
                'department': coordinator.department,
                'assigned_rooms': room_list
            }), 200

    except Exception as e:
        logger.error(f"Error getting coordinator rooms: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/get-class-rep-rooms/<username>', methods=['GET'])
@cross_origin()
def get_class_rep_rooms(username):
    """Get rooms assigned to a class representative."""
    try:
        with engine.begin() as conn:
            class_reps_table = Table('class_representatives', metadata, autoload_with=engine)
            rooms_table = Table('rooms', metadata, autoload_with=engine)

            # Get class rep
            class_rep = conn.execute(
                select(class_reps_table).where(class_reps_table.c.username == username)
            ).fetchone()

            if not class_rep:
                return jsonify({'success': False, 'error': 'Class representative not found'}), 404

            assigned_rooms = json.loads(class_rep.assigned_rooms) if class_rep.assigned_rooms else []

            # Get room details
            if assigned_rooms:
                rooms = conn.execute(
                    select(rooms_table).where(rooms_table.c.room_id.in_(assigned_rooms))
                ).fetchall()

                room_list = [{
                    'id': room.id,
                    'room_id': room.room_id,
                    'room_name': room.room_name,
                    'floor_number': room.floor_number,
                    'department': room.department,
                    'threshold': room.threshold,
                } for room in rooms]
            else:
                room_list = []

            return jsonify({
                'success': True,
                'username': username,
                'department': class_rep.department,
                'year': class_rep.year,
                'section': class_rep.section,
                'assigned_rooms': room_list
            }), 200

    except Exception as e:
        logger.error(f"Error getting class rep rooms: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/rooms/<department>', methods=['GET'])
@cross_origin()
def get_department_rooms(department):
    """Get all rooms assigned to a department."""
    try:
        with engine.begin() as conn:
            rooms_table = Table('rooms', metadata, autoload_with=engine)

            rooms = conn.execute(
                select(rooms_table).where(rooms_table.c.department == department)
            ).fetchall()

            room_list = [{
                'id': room.id,
                'room_id': room.room_id,
                'room_name': room.room_name,
                'floor_number': room.floor_number,
                'department': room.department,
                'threshold': room.threshold,
            } for room in rooms]

            return jsonify({
                'success': True,
                'department': department,
                'rooms': room_list,
                'total_rooms': len(room_list)
            }), 200

    except Exception as e:
        logger.error(f"Error getting department rooms: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/coordinators/<department>', methods=['GET'])
@cross_origin()
def get_department_coordinators(department):
    """Get all coordinators in a department."""
    try:
        with engine.begin() as conn:
            coordinators_table = Table('coordinators', metadata, autoload_with=engine)

            coordinators = conn.execute(
                select(coordinators_table).where(coordinators_table.c.department == department)
            ).fetchall()

            coord_list = [{
                'id': coordinator.id,
                'coordinator_id': coordinator.coordinator_id,
                'name': coordinator.name,
                'email': coordinator.email,
                'department': coordinator.department,
                'is_active': coordinator.is_active,
                'last_login': coordinator.last_login.isoformat() if coordinator.last_login else None,
            } for coordinator in coordinators]

            return jsonify({
                'success': True,
                'department': department,
                'coordinators': coord_list,
                'total_coordinators': len(coord_list)
            }), 200

    except Exception as e:
        logger.error(f"Error getting department coordinators: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


@dept_api.route('/class-representatives/<department>', methods=['GET'])
@cross_origin()
def get_department_class_reps(department):
    """Get all class representatives in a department."""
    try:
        with engine.begin() as conn:
            class_reps_table = Table('class_representatives', metadata, autoload_with=engine)

            class_reps = conn.execute(
                select(class_reps_table).where(class_reps_table.c.department == department)
            ).fetchall()

            rep_list = [{
                'id': class_rep.id,
                'username': class_rep.username,
                'name': class_rep.name,
                'email': class_rep.email,
                'ktu_id': class_rep.ktu_id,
                'department': class_rep.department,
                'year': class_rep.year,
                'section': class_rep.section,
                'is_active': class_rep.is_active,
                'last_login': class_rep.last_login.isoformat() if class_rep.last_login else None,
            } for class_rep in class_reps]

            return jsonify({
                'success': True,
                'department': department,
                'class_representatives': rep_list,
                'total_class_reps': len(rep_list)
            }), 200

    except Exception as e:
        logger.error(f"Error getting department class reps: {str(e)}")
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    logger.info("Department Customization API loaded")
