#!/bin/bash
# Run sample queries against the telco database
# Usage: ./query-sample-data.sh <project-name>
set -e

PROJECT_NAME="${1:-}"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Usage: $0 <project-name>"
    echo ""
    echo "Example:"
    echo "  $0 demo-standalone"
    exit 1
fi

NAMESPACE="mongodb-${PROJECT_NAME}"

# Get NodePort
NODEPORT=$(kubectl get svc "${PROJECT_NAME}-external" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)

if [[ -z "$NODEPORT" ]]; then
    echo "Error: Service '${PROJECT_NAME}-external' not found"
    exit 1
fi

CONNECTION_STRING="mongodb://dbUser:MongoDBPass123!@192.168.139.2:${NODEPORT}/admin"

echo "Running sample queries against: $PROJECT_NAME"
echo ""

mongosh "$CONNECTION_STRING" --quiet --eval '
db = db.getSiblingDB("telco");

print("=".repeat(60));
print("QUERY 1: Active Subscribers with Plan Details");
print("=".repeat(60));
print("");

db.subscribers.aggregate([
  { $match: { status: "active" } },
  { $lookup: {
      from: "plans",
      localField: "planId",
      foreignField: "_id",
      as: "plan"
  }},
  { $unwind: "$plan" },
  { $project: {
      _id: 0,
      name: { $concat: ["$firstName", " ", "$lastName"] },
      phone: "$phoneNumber",
      plan: "$plan.name",
      monthlyPrice: "$plan.monthlyPrice",
      city: "$address.city"
  }}
]).forEach(doc => printjson(doc));

print("");
print("=".repeat(60));
print("QUERY 2: Subscribers Near Data Limit (Basic Plan)");
print("=".repeat(60));
print("");

db.usage.aggregate([
  { $lookup: {
      from: "subscribers",
      localField: "subscriberId",
      foreignField: "_id",
      as: "subscriber"
  }},
  { $unwind: "$subscriber" },
  { $lookup: {
      from: "plans",
      localField: "subscriber.planId",
      foreignField: "_id",
      as: "plan"
  }},
  { $unwind: "$plan" },
  { $match: { "plan.dataGB": { $type: "number" } } },
  { $addFields: {
      dataRemaining: { $subtract: ["$plan.dataGB", "$dataUsedGB"] },
      percentUsed: { $multiply: [{ $divide: ["$dataUsedGB", "$plan.dataGB"] }, 100] }
  }},
  { $match: { percentUsed: { $gte: 80 } } },
  { $project: {
      _id: 0,
      name: { $concat: ["$subscriber.firstName", " ", "$subscriber.lastName"] },
      plan: "$plan.name",
      dataLimit: "$plan.dataGB",
      dataUsed: "$dataUsedGB",
      percentUsed: { $round: ["$percentUsed", 1] }
  }}
]).forEach(doc => printjson(doc));

print("");
print("=".repeat(60));
print("QUERY 3: Revenue Summary by Plan");
print("=".repeat(60));
print("");

db.subscribers.aggregate([
  { $match: { status: "active" } },
  { $lookup: {
      from: "plans",
      localField: "planId",
      foreignField: "_id",
      as: "plan"
  }},
  { $unwind: "$plan" },
  { $group: {
      _id: "$plan.name",
      subscriberCount: { $sum: 1 },
      monthlyRevenue: { $sum: "$plan.monthlyPrice" }
  }},
  { $project: {
      _id: 0,
      plan: "$_id",
      subscribers: "$subscriberCount",
      monthlyRevenue: { $round: ["$monthlyRevenue", 2] }
  }},
  { $sort: { monthlyRevenue: -1 } }
]).forEach(doc => printjson(doc));

print("");
print("=".repeat(60));
'

echo ""
echo "Queries complete!"
