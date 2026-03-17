// Sample telco data for MongoDB demos
// Usage: mongosh <connection-string> scripts/sample-data.js

// Switch to telco database
db = db.getSiblingDB("telco");

// Drop existing collections for clean reload
db.plans.drop();
db.subscribers.drop();
db.usage.drop();

// ============================================
// Plans Collection - Service plans offered
// ============================================
db.plans.insertMany([
  {
    _id: "plan-basic",
    name: "Basic",
    monthlyPrice: 29.99,
    dataGB: 5,
    minutesIncluded: 500,
    smsIncluded: 500,
    features: ["Voicemail", "Caller ID"]
  },
  {
    _id: "plan-standard",
    name: "Standard",
    monthlyPrice: 49.99,
    dataGB: 15,
    minutesIncluded: "unlimited",
    smsIncluded: "unlimited",
    features: ["Voicemail", "Caller ID", "WiFi Calling", "HD Voice"]
  },
  {
    _id: "plan-premium",
    name: "Premium",
    monthlyPrice: 79.99,
    dataGB: "unlimited",
    minutesIncluded: "unlimited",
    smsIncluded: "unlimited",
    features: ["Voicemail", "Caller ID", "WiFi Calling", "HD Voice", "International Roaming", "Priority Support"]
  }
]);

print("Inserted 3 plans");

// ============================================
// Subscribers Collection - Customer accounts
// ============================================
db.subscribers.insertMany([
  {
    _id: "sub-1001",
    phoneNumber: "+1-512-555-0101",
    firstName: "Alice",
    lastName: "Johnson",
    email: "alice.johnson@email.com",
    planId: "plan-premium",
    status: "active",
    activatedDate: ISODate("2023-03-15"),
    address: {
      street: "123 Main St",
      city: "Austin",
      state: "TX",
      zip: "78701"
    },
    preferences: {
      paperlessBilling: true,
      autopay: true
    }
  },
  {
    _id: "sub-1002",
    phoneNumber: "+1-512-555-0102",
    firstName: "Bob",
    lastName: "Smith",
    email: "bob.smith@email.com",
    planId: "plan-standard",
    status: "active",
    activatedDate: ISODate("2023-06-20"),
    address: {
      street: "456 Oak Ave",
      city: "Austin",
      state: "TX",
      zip: "78702"
    },
    preferences: {
      paperlessBilling: true,
      autopay: false
    }
  },
  {
    _id: "sub-1003",
    phoneNumber: "+1-512-555-0103",
    firstName: "Carol",
    lastName: "Davis",
    email: "carol.davis@email.com",
    planId: "plan-basic",
    status: "active",
    activatedDate: ISODate("2024-01-10"),
    address: {
      street: "789 Pine Rd",
      city: "Round Rock",
      state: "TX",
      zip: "78664"
    },
    preferences: {
      paperlessBilling: false,
      autopay: true
    }
  },
  {
    _id: "sub-1004",
    phoneNumber: "+1-512-555-0104",
    firstName: "David",
    lastName: "Wilson",
    email: "david.wilson@email.com",
    planId: "plan-premium",
    status: "active",
    activatedDate: ISODate("2022-11-05"),
    address: {
      street: "321 Elm St",
      city: "Cedar Park",
      state: "TX",
      zip: "78613"
    },
    preferences: {
      paperlessBilling: true,
      autopay: true
    }
  },
  {
    _id: "sub-1005",
    phoneNumber: "+1-512-555-0105",
    firstName: "Eva",
    lastName: "Martinez",
    email: "eva.martinez@email.com",
    planId: "plan-standard",
    status: "suspended",
    activatedDate: ISODate("2023-08-12"),
    suspendedDate: ISODate("2024-02-01"),
    suspendReason: "non-payment",
    address: {
      street: "555 Cedar Ln",
      city: "Georgetown",
      state: "TX",
      zip: "78626"
    },
    preferences: {
      paperlessBilling: false,
      autopay: false
    }
  }
]);

print("Inserted 5 subscribers");

// ============================================
// Usage Collection - Call/Data/SMS records
// ============================================
db.usage.insertMany([
  // Alice - Premium user, heavy data
  {
    subscriberId: "sub-1001",
    billingPeriod: "2024-03",
    dataUsedGB: 45.2,
    minutesUsed: 320,
    smsCount: 150,
    internationalMinutes: 45,
    roamingDataGB: 2.1
  },
  // Bob - Standard user
  {
    subscriberId: "sub-1002",
    billingPeriod: "2024-03",
    dataUsedGB: 12.8,
    minutesUsed: 890,
    smsCount: 420,
    internationalMinutes: 0,
    roamingDataGB: 0
  },
  // Carol - Basic user, near limit
  {
    subscriberId: "sub-1003",
    billingPeriod: "2024-03",
    dataUsedGB: 4.9,
    minutesUsed: 485,
    smsCount: 210,
    internationalMinutes: 0,
    roamingDataGB: 0
  },
  // David - Premium, moderate use
  {
    subscriberId: "sub-1004",
    billingPeriod: "2024-03",
    dataUsedGB: 28.5,
    minutesUsed: 156,
    smsCount: 89,
    internationalMinutes: 120,
    roamingDataGB: 5.0
  },
  // Eva - Suspended, last usage before suspension
  {
    subscriberId: "sub-1005",
    billingPeriod: "2024-01",
    dataUsedGB: 8.2,
    minutesUsed: 445,
    smsCount: 312,
    internationalMinutes: 0,
    roamingDataGB: 0
  }
]);

print("Inserted 5 usage records");

// Create indexes for common queries
db.subscribers.createIndex({ phoneNumber: 1 }, { unique: true });
db.subscribers.createIndex({ status: 1 });
db.subscribers.createIndex({ planId: 1 });
db.usage.createIndex({ subscriberId: 1, billingPeriod: 1 });

print("Created indexes");

// Summary
print("");
print("=== Telco Database Ready ===");
print("Database: telco");
print("Collections: plans, subscribers, usage");
print("");
print("Sample queries:");
print("  db.subscribers.find({ status: \"active\" })");
print("  db.subscribers.find({ planId: \"plan-premium\" })");
print("  db.usage.find({ subscriberId: \"sub-1001\" })");
print("  db.plans.find()");
