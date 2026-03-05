# Active Rooms Feature - Coordinator Dashboard

## Overview
Added an interactive "Active Rooms" section to the Coordinator Dashboard that displays real-time details of active rooms in the CS department.

## Features Implemented

### 1. Active Rooms Card Display
- **Location**: Department Overview section, between Department Stats and Top Energy Consumers
- **Layout**: Horizontal scrollable cards (200px width each)
- **Content per card**:
  - Room number/identifier
  - Current status (Normal, High Usage, Moderate, etc.)
  - Energy usage in kW
  - Active status indicator with green dot
  - "Tap for details" hint

### 2. Visual Design
- **Card styling**:
  - Gradient background based on room status color
  - Border with transparency effect
  - Elevation shadow for depth
  - Rounded corners (16px radius)

- **Status color coding**:
  - Green: Normal
  - Red: High Usage
  - Orange: Moderate
  - Purple: Critical System
  - Blue: Low Usage
  - Grey: Offline

### 3. Interactive Details Dialog
When a room card is clicked, a detailed modal dialog appears showing:

- **Room Information**:
  - Room number with icon
  - Status badge
  - Energy usage
  - Active status indicator

- **Quick Stats**:
  - Uptime (e.g., 2h 34m)
  - Efficiency percentage

- **Visual Elements**:
  - Header with room icon and close button
  - Divider lines for visual separation
  - Color-coded icons for each detail
  - Custom stat boxes with icon and color scheme

### 4. Dynamic Updates
- Rooms update in real-time when new rooms become active
- Uses the existing `_activateRandomRoom()` function
- Supports the "Simulate Room Activation" button
- Automatically displays newly activated rooms

## Code Structure

### Main Components
1. **_buildActiveRoomCard()**: Creates individual room card widgets
2. **_showActiveRoomDetailsDialog()**: Displays detailed information modal
3. **_buildDetailRow()**: Helper for detail rows in the dialog
4. **_buildStatBox()**: Helper for statistics boxes

### Integration Points
- Connected to existing `activeRooms` list passed from `_CoordinatorDashboardPageState`
- Uses existing room data structure: `{'room': string, 'status': string, 'usage': string, 'isActive': bool}`
- Compatible with existing color scheme and theme system

## User Experience Flow
1. User views Overview tab in Coordinator Dashboard
2. Sees "Active Rooms" section with scrollable cards
3. Each card shows room number, status, and energy usage
4. User taps a card to see detailed information
5. Modal dialog opens with comprehensive room details
6. User can close dialog and view other rooms

## Files Modified
- `lib/coordinator_dashboard.dart`: Added new methods and UI components

## Future Enhancements
- Real-time sensor data integration
- Room control options (turn on/off)
- Historical usage trends
- Automated alerts for status changes
- Multi-room comparison
