/// Example JSON structures and API usage for Hostel Hierarchy System
library;

// ==================== EXAMPLE JSON STRUCTURES ====================

/// Example Hostel JSON
const exampleHostelJson = {
  "id": "hostel_abc123",
  "name": "Boys Hostel Alpha",
  "type": "boys",
  "description": "Main boys hostel with modern facilities",
  "address": "Campus Block A",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
};

/// Example Hall JSON
const exampleHallJson = {
  "id": "hall_xyz789",
  "hostelId": "hostel_abc123",
  "name": "North Hall",
  "description": "North wing of boys hostel",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
};

/// Example Floor JSON
const exampleFloorJson = {
  "id": "floor_def456",
  "hallId": "hall_xyz789",
  "name": "Ground Floor",
  "floorNumber": 0,
  "description": "Ground level floor",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
};

/// Example Room JSON
const exampleRoomJson = {
  "id": "room_ghi789",
  "floorId": "floor_def456",
  "name": "Room 101",
  "capacity": 2,
  "occupied": 0,
  "isAvailable": true,
  "description": "Double occupancy room",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
};

/// Example Complete Hierarchy JSON
const exampleHierarchyJson = {
  "hostel": {
    "name": "Boys Hostel Alpha",
    "type": "boys",
    "description": "Main boys hostel",
    "address": "Campus Block A",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  "hall": {
    "hostelId": "hostel_abc123",
    "name": "North Hall",
    "description": "North wing",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  "floor": {
    "hallId": "hall_xyz789",
    "name": "Ground Floor",
    "floorNumber": 0,
    "description": "Ground level",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  "room": {
    "floorId": "floor_def456",
    "name": "Room 101",
    "capacity": 2,
    "occupied": 0,
    "isAvailable": true,
    "description": "Double occupancy",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
};

// ==================== EXAMPLE API REQUESTS ====================

/// Example: POST /hostels
const createHostelRequest = {
  "name": "Boys Hostel Alpha",
  "type": "boys",
  "description": "Main boys hostel with modern facilities",
  "address": "Campus Block A"
};

/// Example: POST /hostels/:id/halls
const createHallRequest = {
  "name": "North Hall",
  "description": "North wing of boys hostel"
};

/// Example: POST /halls/:id/floors
const createFloorRequest = {
  "name": "Ground Floor",
  "floorNumber": 0,
  "description": "Ground level floor"
};

/// Example: POST /floors/:id/rooms
const createRoomRequest = {
  "name": "Room 101",
  "capacity": 2,
  "description": "Double occupancy room"
};

/// Example: PUT /rooms/:id
const updateRoomRequest = {
  "name": "Room 101A",
  "capacity": 3,
  "description": "Updated to triple occupancy"
};

// ==================== EXAMPLE API RESPONSES ====================

/// Example: POST Response
const createResponse = {
  "id": "abc123",
  "message": "Hostel created successfully"
};

/// Example: GET /hostels Response
const getHostelsResponse = [
  {
    "id": "hostel_abc123",
    "name": "Boys Hostel Alpha",
    "type": "boys",
    "description": "Main boys hostel",
    "address": "Campus Block A",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  {
    "id": "hostel_def456",
    "name": "Girls Hostel Beta",
    "type": "girls",
    "description": "Main girls hostel",
    "address": "Campus Block B",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
];

/// Example: GET /hostels/:id/halls Response
const getHallsResponse = [
  {
    "id": "hall_xyz789",
    "hostelId": "hostel_abc123",
    "name": "North Hall",
    "description": "North wing",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  {
    "id": "hall_abc456",
    "hostelId": "hostel_abc123",
    "name": "South Hall",
    "description": "South wing",
    "isActive": true,
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
];

/// Example: GET /floors/:id/rooms Response
const getRoomsResponse = [
  {
    "id": "room_ghi789",
    "floorId": "floor_def456",
    "name": "Room 101",
    "capacity": 2,
    "occupied": 0,
    "isAvailable": true,
    "description": "Double occupancy",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  },
  {
    "id": "room_jkl012",
    "floorId": "floor_def456",
    "name": "Room 102",
    "capacity": 3,
    "occupied": 1,
    "isAvailable": true,
    "description": "Triple occupancy",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
];

/// Example: Error Response
const errorResponse = {
  "error": "Failed to create room: Room capacity must be at least 1",
  "code": "VALIDATION_ERROR"
};

