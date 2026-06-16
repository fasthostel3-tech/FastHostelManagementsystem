/// ==================== API EXAMPLES ====================
/// 
/// This file contains example API requests and responses
/// for the Hostel Hierarchy Management System
/// 
/// All endpoints follow RESTful conventions
/// Base URL: /api/v1

/// ==================== HOSTEL ENDPOINTS ====================

/// POST /hostels
/// Create a new hostel
/// 
/// Request:
/// ```json
/// {
///   "name": "Boys Hostel A",
///   "type": "boys",
///   "description": "Main boys hostel with modern facilities"
/// }
/// ```
/// 
/// Response (201 Created):
/// ```json
/// {
///   "id": "hostel-uuid-123",
///   "name": "Boys Hostel A",
///   "type": "boys",
///   "gender": "male",
///   "description": "Main boys hostel with modern facilities",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Hostel name is required"
/// }
/// ```

/// GET /hostels
/// Get all hostels
/// 
/// Response (200 OK):
/// ```json
/// [
///   {
///     "id": "hostel-uuid-123",
///     "name": "Boys Hostel A",
///     "type": "boys",
///     "gender": "male",
///     "description": "Main boys hostel",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   },
///   {
///     "id": "hostel-uuid-456",
///     "name": "Girls Hostel A",
///     "type": "girls",
///     "gender": "female",
///     "description": "Main girls hostel",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   }
/// ]
/// ```

/// GET /hostels/:id
/// Get a specific hostel
/// 
/// Response (200 OK):
/// ```json
/// {
///   "id": "hostel-uuid-123",
///   "name": "Boys Hostel A",
///   "type": "boys",
///   "gender": "male",
///   "description": "Main boys hostel",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```
/// 
/// Error Response (404 Not Found):
/// ```json
/// {
///   "error": "Hostel not found"
/// }
/// ```

/// PUT /hostels/:id
/// Update a hostel
/// 
/// Request:
/// ```json
/// {
///   "name": "Boys Hostel A - Updated",
///   "description": "Updated description"
/// }
/// ```
/// 
/// Response (200 OK):
/// ```json
/// {
///   "message": "Hostel updated successfully"
/// }
/// ```

/// DELETE /hostels/:id
/// Delete a hostel
/// 
/// Response (200 OK):
/// ```json
/// {
///   "message": "Hostel deleted successfully"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Cannot delete hostel: halls still exist. Delete halls first."
/// }
/// ```

/// ==================== HALL ENDPOINTS ====================

/// POST /hostels/:hostelId/halls
/// Create a hall in a hostel
/// 
/// Request:
/// ```json
/// {
///   "name": "North Hall",
///   "description": "North wing of the hostel"
/// }
/// ```
/// 
/// Response (201 Created):
/// ```json
/// {
///   "id": "hall-uuid-123",
///   "hostelId": "hostel-uuid-123",
///   "name": "North Hall",
///   "description": "North wing of the hostel",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```
/// 
/// Error Response (404 Not Found):
/// ```json
/// {
///   "error": "Hostel not found"
/// }
/// ```

/// GET /hostels/:hostelId/halls
/// Get all halls for a hostel
/// 
/// Response (200 OK):
/// ```json
/// [
///   {
///     "id": "hall-uuid-123",
///     "hostelId": "hostel-uuid-123",
///     "name": "North Hall",
///     "description": "North wing",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   },
///   {
///     "id": "hall-uuid-456",
///     "hostelId": "hostel-uuid-123",
///     "name": "South Hall",
///     "description": "South wing",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   }
/// ]
/// ```

/// GET /halls/:id
/// Get a specific hall
/// 
/// Response (200 OK):
/// ```json
/// {
///   "id": "hall-uuid-123",
///   "hostelId": "hostel-uuid-123",
///   "name": "North Hall",
///   "description": "North wing",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```

/// PUT /halls/:id
/// Update a hall
/// 
/// Request:
/// ```json
/// {
///   "name": "North Hall - Updated",
///   "description": "Updated description"
/// }
/// ```

/// DELETE /halls/:id
/// Delete a hall
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Cannot delete hall: floors still exist. Delete floors first."
/// }
/// ```

/// ==================== FLOOR ENDPOINTS ====================

/// POST /halls/:hallId/floors
/// Create a floor in a hall
/// 
/// Request:
/// ```json
/// {
///   "name": "Ground Floor",
///   "floorNumber": 0,
///   "description": "Ground level floor"
/// }
/// ```
/// 
/// Response (201 Created):
/// ```json
/// {
///   "id": "floor-uuid-123",
///   "hallId": "hall-uuid-123",
///   "name": "Ground Floor",
///   "floorNumber": 0,
///   "description": "Ground level floor",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Floor number must be >= 0"
/// }
/// ```

/// GET /halls/:hallId/floors
/// Get all floors for a hall
/// 
/// Response (200 OK):
/// ```json
/// [
///   {
///     "id": "floor-uuid-123",
///     "hallId": "hall-uuid-123",
///     "name": "Ground Floor",
///     "floorNumber": 0,
///     "description": "Ground level",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   },
///   {
///     "id": "floor-uuid-456",
///     "hallId": "hall-uuid-123",
///     "name": "First Floor",
///     "floorNumber": 1,
///     "description": "First level",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   }
/// ]
/// ```

/// GET /floors/:id
/// Get a specific floor

/// PUT /floors/:id
/// Update a floor
/// 
/// Request:
/// ```json
/// {
///   "name": "Ground Floor - Updated",
///   "floorNumber": 0
/// }
/// ```

/// DELETE /floors/:id
/// Delete a floor
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Cannot delete floor: rooms still exist. Delete rooms first."
/// }
/// ```

/// ==================== ROOM ENDPOINTS ====================

/// POST /floors/:floorId/rooms
/// Create a room in a floor
/// 
/// Request:
/// ```json
/// {
///   "name": "Room 101",
///   "capacity": 2,
///   "description": "Room 101 on Ground Floor"
/// }
/// ```
/// 
/// Response (201 Created):
/// ```json
/// {
///   "id": "room-uuid-123",
///   "floorId": "floor-uuid-123",
///   "name": "Room 101",
///   "capacity": 2,
///   "occupied": 0,
///   "isAvailable": true,
///   "description": "Room 101 on Ground Floor",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Room capacity must be >= 1"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Room capacity cannot exceed 10"
/// }
/// ```

/// GET /floors/:floorId/rooms
/// Get all rooms for a floor
/// 
/// Response (200 OK):
/// ```json
/// [
///   {
///     "id": "room-uuid-123",
///     "floorId": "floor-uuid-123",
///     "name": "Room 101",
///     "capacity": 2,
///     "occupied": 0,
///     "isAvailable": true,
///     "description": "Room 101",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   },
///   {
///     "id": "room-uuid-456",
///     "floorId": "floor-uuid-123",
///     "name": "Room 102",
///     "capacity": 3,
///     "occupied": 1,
///     "isAvailable": true,
///     "description": "Room 102",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   }
/// ]
/// ```

/// GET /rooms/:id
/// Get a specific room
/// 
/// Response (200 OK):
/// ```json
/// {
///   "id": "room-uuid-123",
///   "floorId": "floor-uuid-123",
///   "name": "Room 101",
///   "capacity": 2,
///   "occupied": 0,
///   "isAvailable": true,
///   "description": "Room 101",
///   "createdAt": "2024-01-15T10:30:00Z",
///   "updatedAt": "2024-01-15T10:30:00Z"
/// }
/// ```

/// PUT /rooms/:id
/// Update a room
/// 
/// Request:
/// ```json
/// {
///   "name": "Room 101 - Updated",
///   "capacity": 3,
///   "description": "Updated description"
/// }
/// ```
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Cannot reduce capacity below current occupancy (2)"
/// }
/// ```

/// DELETE /rooms/:id
/// Delete a room
/// 
/// Error Response (400 Bad Request):
/// ```json
/// {
///   "error": "Cannot delete room: room is occupied. Remove occupants first."
/// }
/// ```

/// ==================== HIERARCHY ENDPOINT ====================

/// GET /hostels/:id/hierarchy
/// Get full hierarchy for a hostel (hostel → halls → floors → rooms)
/// 
/// Response (200 OK):
/// ```json
/// {
///   "hostel": {
///     "id": "hostel-uuid-123",
///     "name": "Boys Hostel A",
///     "type": "boys",
///     "gender": "male",
///     "description": "Main boys hostel",
///     "createdAt": "2024-01-15T10:30:00Z",
///     "updatedAt": "2024-01-15T10:30:00Z"
///   },
///   "halls": [
///     {
///       "hall": {
///         "id": "hall-uuid-123",
///         "hostelId": "hostel-uuid-123",
///         "name": "North Hall",
///         "description": "North wing",
///         "createdAt": "2024-01-15T10:30:00Z",
///         "updatedAt": "2024-01-15T10:30:00Z"
///       },
///       "floors": [
///         {
///           "floor": {
///             "id": "floor-uuid-123",
///             "hallId": "hall-uuid-123",
///             "name": "Ground Floor",
///             "floorNumber": 0,
///             "createdAt": "2024-01-15T10:30:00Z",
///             "updatedAt": "2024-01-15T10:30:00Z"
///           },
///           "rooms": [
///             {
///               "id": "room-uuid-123",
///               "floorId": "floor-uuid-123",
///               "name": "Room 101",
///               "capacity": 2,
///               "occupied": 0,
///               "isAvailable": true,
///               "createdAt": "2024-01-15T10:30:00Z",
///               "updatedAt": "2024-01-15T10:30:00Z"
///             }
///           ]
///         }
///       ]
///     }
///   ]
/// }
/// ```

/// ==================== ERROR RESPONSES ====================
/// 
/// All endpoints may return these error responses:
/// 
/// 400 Bad Request:
/// ```json
/// {
///   "error": "Validation error message"
/// }
/// ```
/// 
/// 404 Not Found:
/// ```json
/// {
///   "error": "Resource not found"
/// }
/// ```
/// 
/// 500 Internal Server Error:
/// ```json
/// {
///   "error": "Internal server error message"
/// }
/// ```

