const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const multer = require('multer');
const xlsx = require('xlsx');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/hospital_finder';

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('✅ MongoDB Connected Successfully'))
.catch(err => console.error('❌ MongoDB Connection Error:', err));

// Hospital Schema with geospatial indexing
const hospitalSchema = new mongoose.Schema({
  srNo: String,
  name: { type: String, required: true, index: true },
  category: { type: String, index: true },
  discipline: String,
  address: String,
  state: { type: String, index: true },
  district: { type: String, index: true },
  pincode: String,
  telephone: String,
  emergencyNum: String,
  bloodbankPhone: String,
  email: String,
  website: String,
  specialties: [String],
  facilities: [String],
  accreditation: String,
  ayush: String,
  totalBeds: Number,
  availableBeds: { type: Number, index: true },
  privateWards: Number,
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true
    }
  },
  locationCoordinates: String,
  dormentry: String
}, {
  timestamps: true
});

// Create 2dsphere index for geospatial queries
hospitalSchema.index({ location: '2dsphere' });
hospitalSchema.index({ name: 'text', address: 'text', district: 'text', state: 'text' });

const Hospital = mongoose.model('Hospital', hospitalSchema);

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// ==================== ROUTES ====================

// Health Check
app.get('/api/health', async (req, res) => {
  try {
    const mongoStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';
    const hospitalCount = await Hospital.countDocuments();
    
    res.json({
      status: 'ok',
      message: 'Hospital Finder API is running',
      mongodb: mongoStatus,
      totalHospitals: hospitalCount,
      version: '1.0.0',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      message: 'Health check failed',
      error: error.message
    });
  }
});

// Get ALL hospitals (no limit)
app.get('/api/hospitals', async (req, res) => {
  try {
    console.log('📡 Fetching all hospitals...');
    
    const hospitals = await Hospital.find({})
      .select('-__v')
      .lean();

    console.log(`✅ Found ${hospitals.length} hospitals`);

    res.json(hospitals);
  } catch (error) {
    console.error('❌ Error fetching hospitals:', error);
    res.status(500).json({
      error: 'Failed to fetch hospitals',
      message: error.message
    });
  }
});

// Get nearby hospitals with NO LIMIT
app.get('/api/hospitals/nearby', async (req, res) => {
  try {
    const { lat, lng, radius = 50 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        error: 'Latitude and longitude are required',
        message: 'Please provide lat and lng query parameters'
      });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusInMeters = parseFloat(radius) * 1000;

    console.log(`🎯 Finding hospitals within ${radius}km of [${latitude}, ${longitude}]`);

    const hospitals = await Hospital.find({
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: [longitude, latitude]
          },
          $maxDistance: radiusInMeters
        }
      }
    }).select('-__v').lean();

    console.log(`✅ Found ${hospitals.length} nearby hospitals`);

    res.json(hospitals);
  } catch (error) {
    console.error('❌ Error finding nearby hospitals:', error);
    res.status(500).json({
      error: 'Failed to find nearby hospitals',
      message: error.message
    });
  }
});

// Advanced search with NO LIMIT
app.get('/api/hospitals/search', async (req, res) => {
  try {
    const {
      state,
      district,
      name,
      category,
      specialty,
      minAvailableBeds,
      searchText
    } = req.query;

    console.log('🔍 Search parameters:', req.query);

    const query = {};

    if (state) query.state = new RegExp(state, 'i');
    if (district) query.district = new RegExp(district, 'i');
    if (name) query.name = new RegExp(name, 'i');
    if (category) query.category = new RegExp(category, 'i');
    if (specialty) query.specialties = new RegExp(specialty, 'i');
    if (minAvailableBeds) query.availableBeds = { $gte: parseInt(minAvailableBeds) };

    // Text search across multiple fields
    if (searchText) {
      query.$or = [
        { name: new RegExp(searchText, 'i') },
        { address: new RegExp(searchText, 'i') },
        { district: new RegExp(searchText, 'i') },
        { state: new RegExp(searchText, 'i') },
        { specialties: new RegExp(searchText, 'i') }
      ];
    }

    const hospitals = await Hospital.find(query)
      .select('-__v')
      .lean();

    console.log(`✅ Search returned ${hospitals.length} hospitals`);

    res.json(hospitals);
  } catch (error) {
    console.error('❌ Search error:', error);
    res.status(500).json({
      error: 'Search failed',
      message: error.message
    });
  }
});

// Get hospital by ID
app.get('/api/hospitals/:id', async (req, res) => {
  try {
    const hospital = await Hospital.findById(req.params.id).select('-__v');
    
    if (!hospital) {
      return res.status(404).json({
        error: 'Hospital not found',
        message: `No hospital found with ID: ${req.params.id}`
      });
    }

    res.json(hospital);
  } catch (error) {
    console.error('❌ Error fetching hospital:', error);
    res.status(500).json({
      error: 'Failed to fetch hospital',
      message: error.message
    });
  }
});

// Get statistics
app.get('/api/hospitals/stats', async (req, res) => {
  try {
    const totalHospitals = await Hospital.countDocuments();
    const totalBeds = await Hospital.aggregate([
      { $group: { _id: null, total: { $sum: '$totalBeds' } } }
    ]);
    const availableBeds = await Hospital.aggregate([
      { $group: { _id: null, total: { $sum: '$availableBeds' } } }
    ]);
    const byCategory = await Hospital.aggregate([
      { $group: { _id: '$category', count: { $sum: 1 } } }
    ]);
    const byState = await Hospital.aggregate([
      { $group: { _id: '$state', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    res.json({
      totalHospitals,
      totalBeds: totalBeds[0]?.total || 0,
      availableBeds: availableBeds[0]?.total || 0,
      byCategory,
      byState
    });
  } catch (error) {
    console.error('❌ Error fetching stats:', error);
    res.status(500).json({
      error: 'Failed to fetch statistics',
      message: error.message
    });
  }
});

// Upload Excel file and import data
app.post('/api/hospitals/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    console.log('📤 Processing Excel file...');

    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(worksheet);

    console.log(`📊 Found ${data.length} rows in Excel file`);

    let imported = 0;
    let failed = 0;

    for (const row of data) {
      try {
        // Parse coordinates
        let longitude = 0;
        let latitude = 0;

        if (row.Location_Coordinates) {
          const coords = row.Location_Coordinates.toString().split(',').map(c => c.trim());
          if (coords.length >= 2) {
            latitude = parseFloat(coords[0]) || 0;
            longitude = parseFloat(coords[1]) || 0;
          }
        }

        // Parse lists
        const parseList = (value) => {
          if (!value) return [];
          return value.toString().split(',').map(item => item.trim()).filter(item => item);
        };

        const hospitalData = {
          srNo: row.Sr_No?.toString() || '',
          name: row.Hospital_Name || 'Unknown Hospital',
          category: row.Hospital_Category || 'General',
          discipline: row.Discipline_Systems_of_Medicine || '',
          address: row.Address_Original_First_Line || '',
          state: row.State || '',
          district: row.District || '',
          pincode: row.Pincode?.toString() || '',
          telephone: row.Telephone?.toString() || '',
          emergencyNum: row.Emergency_Num?.toString() || '',
          bloodbankPhone: row.Bloodbank_Phone_No?.toString() || '',
          email: row.Hospital_Primary_Email_Id?.toString() || '',
          website: row.Website?.toString() || '',
          specialties: parseList(row.Specialties),
          facilities: parseList(row.Facilities),
          accreditation: row.Accreditation?.toString() || '',
          ayush: row.Ayush?.toString() || '',
          totalBeds: parseInt(row.Total_Num_Beds) || 0,
          availableBeds: parseInt(row.Available_Beds) || 0,
          privateWards: parseInt(row.Number_Private_Wards) || 0,
          location: {
            type: 'Point',
            coordinates: [longitude, latitude]
          },
          locationCoordinates: row.Location_Coordinates?.toString() || '',
          dormentry: row.Dormentry?.toString() || ''
        };

        await Hospital.create(hospitalData);
        imported++;

        if (imported % 100 === 0) {
          console.log(`✅ Imported ${imported} hospitals...`);
        }
      } catch (error) {
        console.error(`❌ Failed to import row:`, error.message);
        failed++;
      }
    }

    console.log(`✅ Import complete: ${imported} success, ${failed} failed`);

    res.json({
      message: 'Import completed',
      imported,
      failed,
      total: data.length
    });
  } catch (error) {
    console.error('❌ Upload error:', error);
    res.status(500).json({
      error: 'Upload failed',
      message: error.message
    });
  }
});

// Delete all hospitals (for testing)
app.delete('/api/hospitals/all', async (req, res) => {
  try {
    const result = await Hospital.deleteMany({});
    console.log(`🗑️ Deleted ${result.deletedCount} hospitals`);
    
    res.json({
      message: 'All hospitals deleted',
      count: result.deletedCount
    });
  } catch (error) {
    console.error('❌ Delete error:', error);
    res.status(500).json({
      error: 'Delete failed',
      message: error.message
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`,
    availableRoutes: [
      'GET /api/health',
      'GET /api/hospitals',
      'GET /api/hospitals/nearby?lat=XX&lng=XX&radius=XX',
      'GET /api/hospitals/search?state=XX&district=XX',
      'GET /api/hospitals/:id',
      'GET /api/hospitals/stats',
      'POST /api/hospitals/upload',
      'DELETE /api/hospitals/all'
    ]
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('❌ Server error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
  ╔═══════════════════════════════════════════════════╗
  ║   🏥 Hospital Finder API Server                   ║
  ║   ✅ Server running on port ${PORT}                  ║
  ║   📡 API: http://localhost:${PORT}/api            ║
  ║   🗄️  MongoDB: ${MONGODB_URI.includes('localhost') ? 'Local' : 'Remote'}                             ║
  ╚═══════════════════════════════════════════════════╝
  `);
});

module.exports = app;