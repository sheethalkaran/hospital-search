const mongoose = require('mongoose');
const xlsx = require('xlsx');
const path = require('path');
const fs = require('fs');

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/hospital_finder';

// Hospital Schema (same as server.js)
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
      type: [Number],
      required: true
    }
  },
  locationCoordinates: String,
  dormentry: String
}, {
  timestamps: true
});

hospitalSchema.index({ location: '2dsphere' });
hospitalSchema.index({ name: 'text', address: 'text', district: 'text', state: 'text' });

const Hospital = mongoose.model('Hospital', hospitalSchema);

// Parse list helper
const parseList = (value) => {
  if (!value) return [];
  return value.toString().split(',').map(item => item.trim()).filter(item => item);
};

// Import data from Excel
async function importData(filePath) {
  try {
    console.log('📊 Reading Excel file:', filePath);
    
    if (!fs.existsSync(filePath)) {
      console.error('❌ File not found:', filePath);
      process.exit(1);
    }

    const workbook = xlsx.readFile(filePath);
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(worksheet);

    console.log(`📋 Found ${data.length} rows in Excel file`);

    // Connect to MongoDB
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    console.log('✅ MongoDB Connected');

    // Clear existing data
    console.log('🗑️  Clearing existing hospitals...');
    const deleted = await Hospital.deleteMany({});
    console.log(`✅ Deleted ${deleted.deletedCount} existing hospitals`);

    let imported = 0;
    let failed = 0;
    const errors = [];

    console.log('📥 Starting import...');

    for (let i = 0; i < data.length; i++) {
      const row = data[i];
      
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
          emergencyNum: row.Emergency_Num?.toString() || '0',
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
          console.log(`✅ Imported ${imported}/${data.length} hospitals...`);
        }
      } catch (error) {
        failed++;
        errors.push({
          row: i + 2, // Excel row number (1-indexed + header)
          name: row.Hospital_Name,
          error: error.message
        });
        
        if (failed <= 10) {
          console.error(`❌ Failed row ${i + 2}:`, error.message);
        }
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 IMPORT SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Successfully imported: ${imported}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`📋 Total rows: ${data.length}`);
    console.log('='.repeat(60));

    if (errors.length > 0 && errors.length <= 20) {
      console.log('\n❌ Error Details:');
      errors.forEach(err => {
        console.log(`   Row ${err.row} (${err.name}): ${err.error}`);
      });
    } else if (errors.length > 20) {
      console.log(`\n❌ Too many errors to display (${errors.length} total)`);
    }

    // Verify import
    const count = await Hospital.countDocuments();
    console.log(`\n✅ Total hospitals in database: ${count}`);

    // Sample check
    const sample = await Hospital.findOne().select('name state district location');
    console.log('\n📍 Sample hospital:', {
      name: sample.name,
      state: sample.state,
      district: sample.district,
      coordinates: sample.location.coordinates
    });

    await mongoose.connection.close();
    console.log('\n✅ Import completed successfully!');
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Import failed:', error);
    process.exit(1);
  }
}

// Get file path from command line or use default
const filePath = process.argv[2] || path.join(__dirname, '../data/hospitals.xlsx');

console.log(`
╔═══════════════════════════════════════════════════╗
║   🏥 Hospital Data Import Script                  ║
║   📁 File: ${path.basename(filePath).padEnd(38)}║
║   🗄️  MongoDB: ${MONGODB_URI.includes('localhost') ? 'Local' : 'Remote'.padEnd(31)}║
╚═══════════════════════════════════════════════════╝
`);

importData(filePath);