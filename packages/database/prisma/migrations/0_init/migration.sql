-- RouteMate required PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "OrganizationType" AS ENUM ('TRANSPORT_UNION', 'TRANSPORT_ASSOCIATION', 'COOPERATIVE', 'PRIVATE_FLEET', 'GOVERNMENT_OPERATOR', 'OTHER');

-- CreateEnum
CREATE TYPE "OrganizationStatus" AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'INACTIVE');

-- CreateEnum
CREATE TYPE "RecordStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "AdministrativeAreaType" AS ENUM ('COUNTRY', 'STATE', 'LGA', 'CITY', 'DISTRICT');

-- CreateEnum
CREATE TYPE "OrganizationUnitType" AS ENUM ('NATIONAL', 'STATE_CHAPTER', 'ZONE', 'BRANCH', 'LOCAL_UNIT');

-- CreateEnum
CREATE TYPE "ParkType" AS ENUM ('TERMINAL', 'MOTOR_PARK', 'BUS_STOP', 'LOADING_POINT', 'DEPOT');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('INVITED', 'ACTIVE', 'SUSPENDED', 'DISABLED');

-- CreateEnum
CREATE TYPE "RoleScope" AS ENUM ('PLATFORM', 'ORGANIZATION', 'UNIT', 'PARK');

-- CreateEnum
CREATE TYPE "Gender" AS ENUM ('FEMALE', 'MALE', 'OTHER', 'NOT_DISCLOSED');

-- CreateEnum
CREATE TYPE "RegistrationStatus" AS ENUM ('PENDING', 'ACTIVE', 'INACTIVE', 'SUSPENDED', 'BLACKLISTED', 'DECEASED');

-- CreateEnum
CREATE TYPE "VehicleRegistrationStatus" AS ENUM ('PENDING', 'ACTIVE', 'INACTIVE', 'SUSPENDED', 'BLACKLISTED', 'RETIRED');

-- CreateEnum
CREATE TYPE "ComplianceStatus" AS ENUM ('UNKNOWN', 'VALID', 'EXPIRING', 'EXPIRED', 'REVIEW_REQUIRED');

-- CreateEnum
CREATE TYPE "DisciplinaryStatus" AS ENUM ('CLEAR', 'WARNING', 'UNDER_INVESTIGATION', 'SUSPENDED', 'BANNED');

-- CreateEnum
CREATE TYPE "ContactType" AS ENUM ('NEXT_OF_KIN', 'EMERGENCY_CONTACT', 'GUARANTOR', 'OTHER');

-- CreateEnum
CREATE TYPE "DriverDocumentType" AS ENUM ('DRIVER_LICENSE', 'UNION_ID', 'IDENTITY_DOCUMENT', 'MEDICAL_CERTIFICATE', 'TRAINING_CERTIFICATE', 'OTHER');

-- CreateEnum
CREATE TYPE "VehicleDocumentType" AS ENUM ('VEHICLE_REGISTRATION', 'INSURANCE', 'ROADWORTHINESS', 'INSPECTION', 'PERMIT', 'OWNERSHIP', 'OTHER');

-- CreateEnum
CREATE TYPE "DocumentVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');

-- CreateEnum
CREATE TYPE "DriverStatusDimension" AS ENUM ('REGISTRATION', 'COMPLIANCE', 'DISCIPLINARY');

-- CreateEnum
CREATE TYPE "DisciplinaryActionType" AS ENUM ('WARNING', 'FINE', 'SUSPENSION', 'ROUTE_SUSPENSION', 'PARK_SUSPENSION', 'BAN', 'REINSTATEMENT');

-- CreateEnum
CREATE TYPE "DisciplinaryActionStatus" AS ENUM ('PENDING', 'ACTIVE', 'COMPLETED', 'REVOKED', 'APPEALED');

-- CreateEnum
CREATE TYPE "OwnerType" AS ENUM ('INDIVIDUAL', 'DRIVER', 'COOPERATIVE', 'COMPANY', 'TRANSPORT_ORGANIZATION', 'GOVERNMENT');

-- CreateEnum
CREATE TYPE "VehicleType" AS ENUM ('DANFO', 'KOROPE', 'MINIBUS', 'BUS', 'TAXI', 'TRICYCLE', 'SHUTTLE', 'OTHER');

-- CreateEnum
CREATE TYPE "AssignmentType" AS ENUM ('PRIMARY', 'TEMPORARY', 'RELIEF');

-- CreateEnum
CREATE TYPE "AssignmentStatus" AS ENUM ('ACTIVE', 'ENDED', 'SUSPENDED');

-- CreateEnum
CREATE TYPE "OwnershipStatus" AS ENUM ('ACTIVE', 'ENDED', 'DISPUTED');

-- CreateEnum
CREATE TYPE "CrewRole" AS ENUM ('CONDUCTOR', 'ASSISTANT', 'OTHER');

-- CreateEnum
CREATE TYPE "ParkRouteRole" AS ENUM ('ORIGIN', 'DESTINATION', 'INTERMEDIATE', 'OPERATING');

-- CreateEnum
CREATE TYPE "QrStatus" AS ENUM ('ACTIVE', 'REVOKED', 'EXPIRED', 'REPLACED');

-- CreateEnum
CREATE TYPE "VerificationResult" AS ENUM ('VALID', 'VEHICLE_SUSPENDED', 'DRIVER_SUSPENDED', 'QR_REVOKED', 'QR_EXPIRED', 'DOCUMENT_EXPIRED', 'UNKNOWN');

-- CreateEnum
CREATE TYPE "PassengerStatus" AS ENUM ('ACTIVE', 'SUSPENDED', 'DISABLED');

-- CreateEnum
CREATE TYPE "JourneyStatus" AS ENUM ('BOARDED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'EMERGENCY');

-- CreateEnum
CREATE TYPE "JourneyEventType" AS ENUM ('QR_SCANNED', 'BOARDING_CONFIRMED', 'TRIP_STARTED', 'TRIP_SHARED', 'LOCATION_UPDATED', 'SAFETY_REPORT', 'EMERGENCY_TRIGGERED', 'TRIP_ENDED', 'TRIP_CANCELLED');

-- CreateEnum
CREATE TYPE "ComplaintCategory" AS ENUM ('FARE_DISPUTE', 'DRIVER_BEHAVIOUR', 'CONDUCTOR_BEHAVIOUR', 'VEHICLE_CONDITION', 'OVERLOADING', 'LOST_PROPERTY', 'SERVICE_QUALITY', 'OTHER');

-- CreateEnum
CREATE TYPE "Severity" AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

-- CreateEnum
CREATE TYPE "ComplaintStatus" AS ENUM ('REPORTED', 'TRIAGED', 'ASSIGNED', 'INVESTIGATING', 'RESOLVED', 'REJECTED', 'CLOSED');

-- CreateEnum
CREATE TYPE "ReporterType" AS ENUM ('PASSENGER', 'ANONYMOUS', 'USER', 'SYSTEM');

-- CreateEnum
CREATE TYPE "IncidentCategory" AS ENUM ('SAFETY', 'SUSPICIOUS_ACTIVITY', 'ONE_CHANCE_SUSPICION', 'THEFT', 'ASSAULT', 'HARASSMENT', 'ACCIDENT', 'DANGEROUS_DRIVING', 'ABDUCTION_SUSPICION', 'VEHICLE_FAILURE', 'OTHER');

-- CreateEnum
CREATE TYPE "IncidentStatus" AS ENUM ('REPORTED', 'TRIAGED', 'ASSIGNED', 'INVESTIGATING', 'ACTION_TAKEN', 'RESOLVED', 'CLOSED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "EvidenceType" AS ENUM ('PHOTO', 'VIDEO', 'AUDIO', 'DOCUMENT', 'TEXT');

-- CreateEnum
CREATE TYPE "LostPropertyCategory" AS ENUM ('PHONE', 'ELECTRONICS', 'WALLET', 'MONEY', 'DOCUMENTS', 'BAG', 'CLOTHING', 'OTHER');

-- CreateEnum
CREATE TYPE "LostPropertyStatus" AS ENUM ('REPORTED', 'INVESTIGATING', 'FOUND', 'RETURNED', 'NOT_FOUND', 'CLOSED');

-- CreateEnum
CREATE TYPE "NotificationRecipientType" AS ENUM ('USER', 'PASSENGER');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'EMAIL', 'SMS', 'WHATSAPP', 'PUSH');

-- CreateEnum
CREATE TYPE "NotificationType" AS ENUM ('GENERAL', 'SECURITY', 'DOCUMENT_EXPIRY', 'REGISTRATION', 'ASSIGNMENT', 'JOURNEY_SHARE', 'COMPLAINT_UPDATE', 'INCIDENT_ALERT', 'INCIDENT_UPDATE', 'LOST_PROPERTY_UPDATE');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('PENDING', 'PROCESSING', 'SENT', 'DELIVERED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "SecurityEventType" AS ENUM ('LOGIN_SUCCESS', 'LOGIN_FAILED', 'LOGOUT', 'PASSWORD_CHANGED', 'PASSWORD_RESET_REQUESTED', 'MFA_ENABLED', 'MFA_DISABLED', 'ACCOUNT_LOCKED', 'SUSPICIOUS_LOGIN', 'ACCESS_DENIED', 'TOKEN_REVOKED', 'QR_VERIFICATION_FAILED');

-- CreateEnum
CREATE TYPE "SettingValueType" AS ENUM ('STRING', 'NUMBER', 'BOOLEAN', 'JSON');

-- CreateTable
CREATE TABLE "organizations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_code" VARCHAR(30) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "short_name" VARCHAR(100),
    "organization_type" "OrganizationType" NOT NULL,
    "registration_number" VARCHAR(100),
    "email" VARCHAR(254),
    "phone" VARCHAR(32),
    "address" TEXT,
    "country_code" CHAR(3) NOT NULL DEFAULT 'NGA',
    "status" "OrganizationStatus" NOT NULL DEFAULT 'PENDING',
    "logo_url" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "organizations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organization_settings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "allow_public_driver_photo" BOOLEAN NOT NULL DEFAULT false,
    "allow_conductor_registration" BOOLEAN NOT NULL DEFAULT false,
    "require_driver_document_verification" BOOLEAN NOT NULL DEFAULT true,
    "require_vehicle_document_verification" BOOLEAN NOT NULL DEFAULT true,
    "allow_anonymous_boarding" BOOLEAN NOT NULL DEFAULT true,
    "enable_trip_sharing" BOOLEAN NOT NULL DEFAULT true,
    "enable_incident_reporting" BOOLEAN NOT NULL DEFAULT true,
    "enable_lost_property" BOOLEAN NOT NULL DEFAULT true,
    "enable_live_tracking" BOOLEAN NOT NULL DEFAULT false,
    "default_country" CHAR(3) NOT NULL DEFAULT 'NGA',
    "default_timezone" VARCHAR(64) NOT NULL DEFAULT 'Africa/Lagos',
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "organization_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "administrative_areas" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(64) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "area_type" "AdministrativeAreaType" NOT NULL,
    "country_code" CHAR(3) NOT NULL,
    "geometry" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "parent_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "administrative_areas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "organization_units" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "code" VARCHAR(40) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "unit_type" "OrganizationUnitType" NOT NULL,
    "address" TEXT,
    "location" JSONB,
    "phone" VARCHAR(32),
    "email" VARCHAR(254),
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "parent_unit_id" UUID,
    "administrative_area_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "organization_units_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "parks" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "park_code" VARCHAR(30) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "address" TEXT,
    "location" JSONB,
    "park_type" "ParkType" NOT NULL DEFAULT 'MOTOR_PARK',
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "capacity" INTEGER,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "organization_unit_id" UUID NOT NULL,
    "administrative_area_id" UUID,
    "manager_user_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "parks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "email" VARCHAR(254),
    "phone" VARCHAR(32),
    "password_hash" TEXT,
    "external_auth_subject" VARCHAR(255),
    "status" "UserStatus" NOT NULL DEFAULT 'INVITED',
    "last_login_at" TIMESTAMPTZ(6),
    "failed_login_attempts" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ(6),
    "mfa_enabled" BOOLEAN NOT NULL DEFAULT false,
    "email_verified_at" TIMESTAMPTZ(6),
    "phone_verified_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "code" VARCHAR(64) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "description" TEXT,
    "is_system" BOOLEAN NOT NULL DEFAULT false,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(100) NOT NULL,
    "name" VARCHAR(150) NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_roles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "scope" "RoleScope" NOT NULL DEFAULT 'ORGANIZATION',
    "valid_from" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "valid_until" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "user_id" UUID NOT NULL,
    "role_id" UUID NOT NULL,
    "organization_unit_id" UUID,
    "park_id" UUID,
    "granted_by_id" UUID,

    CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "role_id" UUID NOT NULL,
    "permission_id" UUID NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "drivers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "driver_code" VARCHAR(30) NOT NULL,
    "first_name" VARCHAR(100) NOT NULL,
    "middle_name" VARCHAR(100),
    "last_name" VARCHAR(100) NOT NULL,
    "date_of_birth" DATE,
    "gender" "Gender" NOT NULL DEFAULT 'NOT_DISCLOSED',
    "phone" VARCHAR(32) NOT NULL,
    "email" VARCHAR(254),
    "photo_url" TEXT,
    "residential_address" TEXT,
    "national_id_reference" TEXT,
    "driver_license_number" VARCHAR(100),
    "driver_license_expiry" DATE,
    "membership_number" VARCHAR(100),
    "registration_status" "RegistrationStatus" NOT NULL DEFAULT 'PENDING',
    "compliance_status" "ComplianceStatus" NOT NULL DEFAULT 'UNKNOWN',
    "disciplinary_status" "DisciplinaryStatus" NOT NULL DEFAULT 'CLEAR',
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verified_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "organization_unit_id" UUID,
    "primary_park_id" UUID,
    "user_id" UUID,
    "verified_by_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "drivers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_contacts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "contact_type" "ContactType" NOT NULL,
    "name" VARCHAR(200) NOT NULL,
    "relationship" VARCHAR(100),
    "phone" VARCHAR(32) NOT NULL,
    "address" TEXT,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "driver_id" UUID NOT NULL,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "driver_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "document_type" "DriverDocumentType" NOT NULL,
    "document_number" VARCHAR(100),
    "issue_date" DATE,
    "expiry_date" DATE,
    "file_storage_key" TEXT NOT NULL,
    "mime_type" VARCHAR(150),
    "file_size" BIGINT,
    "checksum" VARCHAR(128),
    "verification_status" "DocumentVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "verified_at" TIMESTAMPTZ(6),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "driver_id" UUID NOT NULL,
    "verified_by_id" UUID,
    "uploaded_by_id" UUID,

    CONSTRAINT "driver_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_status_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "dimension" "DriverStatusDimension" NOT NULL,
    "previous_registration_status" "RegistrationStatus",
    "new_registration_status" "RegistrationStatus",
    "previous_compliance_status" "ComplianceStatus",
    "new_compliance_status" "ComplianceStatus",
    "previous_disciplinary_status" "DisciplinaryStatus",
    "new_disciplinary_status" "DisciplinaryStatus",
    "reason" TEXT NOT NULL,
    "changed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "driver_id" UUID NOT NULL,
    "changed_by_id" UUID,

    CONSTRAINT "driver_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_disciplinary_actions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "action_type" "DisciplinaryActionType" NOT NULL,
    "reason" TEXT NOT NULL,
    "effective_from" TIMESTAMPTZ(6) NOT NULL,
    "effective_until" TIMESTAMPTZ(6),
    "status" "DisciplinaryActionStatus" NOT NULL DEFAULT 'PENDING',
    "fine_amount" DECIMAL(14,2),
    "currency" CHAR(3),
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "driver_id" UUID NOT NULL,
    "issued_by_id" UUID NOT NULL,
    "park_id" UUID,
    "route_id" UUID,
    "incident_id" UUID,

    CONSTRAINT "driver_disciplinary_actions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "conductors" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "conductor_code" VARCHAR(30) NOT NULL,
    "first_name" VARCHAR(100) NOT NULL,
    "last_name" VARCHAR(100) NOT NULL,
    "phone" VARCHAR(32) NOT NULL,
    "photo_url" TEXT,
    "membership_number" VARCHAR(100),
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "primary_park_id" UUID,
    "user_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "conductors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_owners" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "owner_type" "OwnerType" NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "phone" VARCHAR(32),
    "email" VARCHAR(254),
    "address" TEXT,
    "identity_reference" TEXT,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "driver_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "vehicle_owners_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicles" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "vehicle_code" VARCHAR(30) NOT NULL,
    "plate_number" VARCHAR(32) NOT NULL,
    "plate_state" VARCHAR(100),
    "plate_country_code" CHAR(3) NOT NULL DEFAULT 'NGA',
    "vehicle_type" "VehicleType" NOT NULL,
    "make" VARCHAR(100),
    "model" VARCHAR(100),
    "year" INTEGER,
    "colour" VARCHAR(50),
    "passenger_capacity" INTEGER NOT NULL,
    "chassis_number" VARCHAR(100),
    "engine_number" VARCHAR(100),
    "registration_status" "VehicleRegistrationStatus" NOT NULL DEFAULT 'PENDING',
    "compliance_status" "ComplianceStatus" NOT NULL DEFAULT 'UNKNOWN',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "primary_owner_id" UUID,
    "primary_park_id" UUID,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "vehicles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_documents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "document_type" "VehicleDocumentType" NOT NULL,
    "document_number" VARCHAR(100),
    "issue_date" DATE,
    "expiry_date" DATE,
    "file_storage_key" TEXT NOT NULL,
    "mime_type" VARCHAR(150),
    "file_size" BIGINT,
    "checksum" VARCHAR(128),
    "verification_status" "DocumentVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "verified_at" TIMESTAMPTZ(6),
    "rejection_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "vehicle_id" UUID NOT NULL,
    "verified_by_id" UUID,
    "uploaded_by_id" UUID,

    CONSTRAINT "vehicle_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_ownership_history" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "start_date" TIMESTAMPTZ(6) NOT NULL,
    "end_date" TIMESTAMPTZ(6),
    "status" "OwnershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "recorded_by_id" UUID,

    CONSTRAINT "vehicle_ownership_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_vehicle_assignments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "assignment_type" "AssignmentType" NOT NULL DEFAULT 'PRIMARY',
    "start_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "end_at" TIMESTAMPTZ(6),
    "status" "AssignmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "driver_id" UUID NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "assigned_by_id" UUID NOT NULL,

    CONSTRAINT "driver_vehicle_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_crew_assignments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "crew_role" "CrewRole" NOT NULL DEFAULT 'CONDUCTOR',
    "start_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "end_at" TIMESTAMPTZ(6),
    "status" "AssignmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "conductor_id" UUID NOT NULL,
    "assigned_by_id" UUID,

    CONSTRAINT "vehicle_crew_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "routes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "route_code" VARCHAR(30) NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "origin_name" VARCHAR(255) NOT NULL,
    "destination_name" VARCHAR(255) NOT NULL,
    "origin_location" JSONB,
    "destination_location" JSONB,
    "route_geometry" JSONB,
    "distance_km" DECIMAL(10,3),
    "estimated_duration_minutes" INTEGER,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "routes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "route_stops" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "name" VARCHAR(255) NOT NULL,
    "location" JSONB,
    "stop_order" INTEGER NOT NULL,
    "estimated_minutes_from_origin" INTEGER,
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "route_id" UUID NOT NULL,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "route_stops_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "park_routes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "route_role" "ParkRouteRole" NOT NULL DEFAULT 'OPERATING',
    "status" "RecordStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "park_id" UUID NOT NULL,
    "route_id" UUID NOT NULL,
    "created_by_id" UUID,
    "updated_by_id" UUID,

    CONSTRAINT "park_routes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_route_assignments" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "start_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "end_at" TIMESTAMPTZ(6),
    "status" "AssignmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "notes" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "route_id" UUID NOT NULL,
    "park_id" UUID,
    "assigned_by_id" UUID NOT NULL,

    CONSTRAINT "vehicle_route_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vehicle_qr_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "public_token_hash" CHAR(64) NOT NULL,
    "token_version" INTEGER NOT NULL DEFAULT 1,
    "issued_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6),
    "revoked_at" TIMESTAMPTZ(6),
    "status" "QrStatus" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "vehicle_id" UUID NOT NULL,
    "issued_by_id" UUID NOT NULL,

    CONSTRAINT "vehicle_qr_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "passenger_sessions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "session_token_hash" CHAR(64) NOT NULL,
    "last_activity_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "passenger_id" UUID,

    CONSTRAINT "passenger_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "passengers" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "first_name" VARCHAR(100),
    "last_name" VARCHAR(100),
    "phone" VARCHAR(32),
    "email" VARCHAR(254),
    "password_hash" TEXT,
    "external_auth_subject" VARCHAR(255),
    "status" "PassengerStatus" NOT NULL DEFAULT 'ACTIVE',
    "phone_verified_at" TIMESTAMPTZ(6),
    "email_verified_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "passengers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trusted_contacts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(200) NOT NULL,
    "phone" VARCHAR(32) NOT NULL,
    "relationship" VARCHAR(100),
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "passenger_id" UUID NOT NULL,

    CONSTRAINT "trusted_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "verification_scans" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "scanned_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "location" JSONB,
    "location_accuracy_meters" DECIMAL(10,2),
    "device_hash" VARCHAR(128),
    "ip_hash" VARCHAR(128),
    "verification_result" "VerificationResult" NOT NULL,
    "user_agent_summary" VARCHAR(512),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "vehicle_id" UUID NOT NULL,
    "qr_code_id" UUID NOT NULL,
    "session_id" UUID,
    "driver_assignment_id" UUID,
    "route_assignment_id" UUID,

    CONSTRAINT "verification_scans_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "journeys" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "journey_code" VARCHAR(30) NOT NULL,
    "boarded_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ended_at" TIMESTAMPTZ(6),
    "boarding_location" JSONB,
    "ending_location" JSONB,
    "status" "JourneyStatus" NOT NULL DEFAULT 'BOARDED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "passenger_id" UUID,
    "passenger_session_id" UUID,
    "vehicle_id" UUID NOT NULL,
    "driver_id" UUID,
    "driver_assignment_id" UUID,
    "route_id" UUID,
    "route_assignment_id" UUID,
    "boarding_park_id" UUID,
    "verification_scan_id" UUID,

    CONSTRAINT "journeys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "journey_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "event_type" "JourneyEventType" NOT NULL,
    "event_time" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "location" JSONB,
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "journey_id" UUID NOT NULL,

    CONSTRAINT "journey_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "journey_shares" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "share_token_hash" CHAR(64) NOT NULL,
    "shared_with_name" VARCHAR(200),
    "shared_with_phone" VARCHAR(32),
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "last_accessed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "journey_id" UUID NOT NULL,
    "trusted_contact_id" UUID,

    CONSTRAINT "journey_shares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complaints" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "complaint_code" VARCHAR(30) NOT NULL,
    "category" "ComplaintCategory" NOT NULL,
    "description" TEXT NOT NULL,
    "severity" "Severity" NOT NULL DEFAULT 'MEDIUM',
    "status" "ComplaintStatus" NOT NULL DEFAULT 'REPORTED',
    "reported_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolved_at" TIMESTAMPTZ(6),
    "resolution_summary" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "passenger_id" UUID,
    "passenger_session_id" UUID,
    "journey_id" UUID,
    "vehicle_id" UUID,
    "driver_id" UUID,
    "park_id" UUID,
    "assigned_to_id" UUID,

    CONSTRAINT "complaints_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complaint_updates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "previous_status" "ComplaintStatus",
    "new_status" "ComplaintStatus",
    "comment" TEXT,
    "is_internal" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "complaint_id" UUID NOT NULL,
    "updated_by_id" UUID,
    "author_passenger_id" UUID,
    "author_session_id" UUID,

    CONSTRAINT "complaint_updates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "incidents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "incident_code" VARCHAR(30) NOT NULL,
    "reporter_type" "ReporterType" NOT NULL,
    "category" "IncidentCategory" NOT NULL,
    "description" TEXT NOT NULL,
    "severity" "Severity" NOT NULL DEFAULT 'HIGH',
    "location" JSONB,
    "reported_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" "IncidentStatus" NOT NULL DEFAULT 'REPORTED',
    "resolved_at" TIMESTAMPTZ(6),
    "resolution" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "journey_id" UUID,
    "vehicle_id" UUID,
    "driver_id" UUID,
    "park_id" UUID,
    "route_id" UUID,
    "reporter_passenger_id" UUID,
    "reporter_session_id" UUID,
    "reporter_user_id" UUID,
    "assigned_to_id" UUID,

    CONSTRAINT "incidents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "incident_evidence" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "evidence_type" "EvidenceType" NOT NULL,
    "file_storage_key" TEXT,
    "text_content" TEXT,
    "mime_type" VARCHAR(150),
    "file_size" BIGINT,
    "checksum" VARCHAR(128),
    "uploaded_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "incident_id" UUID NOT NULL,
    "uploaded_by_id" UUID,
    "uploader_passenger_id" UUID,
    "uploader_session_id" UUID,

    CONSTRAINT "incident_evidence_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "incident_updates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "previous_status" "IncidentStatus",
    "new_status" "IncidentStatus",
    "comment" TEXT,
    "is_internal" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "incident_id" UUID NOT NULL,
    "updated_by_id" UUID,
    "author_passenger_id" UUID,
    "author_session_id" UUID,

    CONSTRAINT "incident_updates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lost_property_cases" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "case_code" VARCHAR(30) NOT NULL,
    "item_category" "LostPropertyCategory" NOT NULL,
    "item_description" TEXT NOT NULL,
    "lost_at" TIMESTAMPTZ(6),
    "reported_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" "LostPropertyStatus" NOT NULL DEFAULT 'REPORTED',
    "found_at" TIMESTAMPTZ(6),
    "returned_at" TIMESTAMPTZ(6),
    "resolution_summary" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    "journey_id" UUID,
    "vehicle_id" UUID,
    "driver_id" UUID,
    "park_id" UUID,
    "passenger_id" UUID,
    "passenger_session_id" UUID,
    "assigned_to_id" UUID,

    CONSTRAINT "lost_property_cases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lost_property_updates" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID NOT NULL,
    "previous_status" "LostPropertyStatus",
    "new_status" "LostPropertyStatus",
    "comment" TEXT,
    "is_internal" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lost_property_case_id" UUID NOT NULL,
    "updated_by_id" UUID,
    "author_passenger_id" UUID,
    "author_session_id" UUID,

    CONSTRAINT "lost_property_updates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "recipient_type" "NotificationRecipientType" NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "notification_type" "NotificationType" NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "message" TEXT NOT NULL,
    "metadata" JSONB,
    "status" "NotificationStatus" NOT NULL DEFAULT 'PENDING',
    "scheduled_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sent_at" TIMESTAMPTZ(6),
    "delivered_at" TIMESTAMPTZ(6),
    "read_at" TIMESTAMPTZ(6),
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMPTZ(6),
    "locked_until" TIMESTAMPTZ(6),
    "last_error" TEXT,
    "provider_message_id" VARCHAR(255),
    "idempotency_key" VARCHAR(128) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "recipient_user_id" UUID,
    "recipient_passenger_id" UUID,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "action" VARCHAR(100) NOT NULL,
    "entity_type" VARCHAR(100) NOT NULL,
    "entity_id" UUID,
    "previous_data" JSONB,
    "new_data" JSONB,
    "ip_hash" VARCHAR(128),
    "device_hash" VARCHAR(128),
    "request_id" VARCHAR(128),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "actor_user_id" UUID,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "security_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "organization_id" UUID,
    "event_type" "SecurityEventType" NOT NULL,
    "severity" "Severity" NOT NULL DEFAULT 'LOW',
    "ip_hash" VARCHAR(128),
    "device_hash" VARCHAR(128),
    "subject_hash" VARCHAR(128),
    "user_agent_summary" VARCHAR(512),
    "request_id" VARCHAR(128),
    "metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "user_id" UUID,
    "passenger_id" UUID,
    "passenger_session_id" UUID,

    CONSTRAINT "security_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "system_settings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "key" VARCHAR(150) NOT NULL,
    "value" JSONB NOT NULL,
    "value_type" "SettingValueType" NOT NULL DEFAULT 'JSON',
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "updated_by_id" UUID,

    CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "organizations_organization_code_key" ON "organizations"("organization_code");

-- CreateIndex
CREATE INDEX "organizations_created_by_id_idx" ON "organizations"("created_by_id");

-- CreateIndex
CREATE INDEX "organizations_updated_by_id_idx" ON "organizations"("updated_by_id");

-- CreateIndex
CREATE INDEX "organization_settings_organization_id_created_at_idx" ON "organization_settings"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "organization_settings_created_by_id_idx" ON "organization_settings"("created_by_id");

-- CreateIndex
CREATE INDEX "organization_settings_updated_by_id_idx" ON "organization_settings"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "organization_settings_organization_id_id_key" ON "organization_settings"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "organization_settings_organization_id_key" ON "organization_settings"("organization_id");

-- CreateIndex
CREATE UNIQUE INDEX "administrative_areas_code_key" ON "administrative_areas"("code");

-- CreateIndex
CREATE INDEX "administrative_areas_parent_id_idx" ON "administrative_areas"("parent_id");

-- CreateIndex
CREATE INDEX "administrative_areas_country_code_area_type_name_idx" ON "administrative_areas"("country_code", "area_type", "name");

-- CreateIndex
CREATE INDEX "administrative_areas_created_by_id_idx" ON "administrative_areas"("created_by_id");

-- CreateIndex
CREATE INDEX "administrative_areas_updated_by_id_idx" ON "administrative_areas"("updated_by_id");

-- CreateIndex
CREATE INDEX "organization_units_organization_id_created_at_idx" ON "organization_units"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "organization_units_organization_id_parent_unit_id_idx" ON "organization_units"("organization_id", "parent_unit_id");

-- CreateIndex
CREATE INDEX "organization_units_administrative_area_id_idx" ON "organization_units"("administrative_area_id");

-- CreateIndex
CREATE INDEX "organization_units_created_by_id_idx" ON "organization_units"("created_by_id");

-- CreateIndex
CREATE INDEX "organization_units_updated_by_id_idx" ON "organization_units"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "organization_units_organization_id_id_key" ON "organization_units"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "organization_units_organization_id_code_key" ON "organization_units"("organization_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "parks_park_code_key" ON "parks"("park_code");

-- CreateIndex
CREATE INDEX "parks_organization_id_created_at_idx" ON "parks"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "parks_organization_id_organization_unit_id_idx" ON "parks"("organization_id", "organization_unit_id");

-- CreateIndex
CREATE INDEX "parks_administrative_area_id_idx" ON "parks"("administrative_area_id");

-- CreateIndex
CREATE INDEX "parks_manager_user_id_idx" ON "parks"("manager_user_id");

-- CreateIndex
CREATE INDEX "parks_created_by_id_idx" ON "parks"("created_by_id");

-- CreateIndex
CREATE INDEX "parks_updated_by_id_idx" ON "parks"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "parks_organization_id_id_key" ON "parks"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "users_external_auth_subject_key" ON "users"("external_auth_subject");

-- CreateIndex
CREATE INDEX "users_created_by_id_idx" ON "users"("created_by_id");

-- CreateIndex
CREATE INDEX "users_updated_by_id_idx" ON "users"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_organization_id_email_key" ON "users"("organization_id", "email");

-- CreateIndex
CREATE UNIQUE INDEX "users_organization_id_phone_key" ON "users"("organization_id", "phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_organization_id_id_key" ON "users"("organization_id", "id");

-- CreateIndex
CREATE INDEX "roles_created_by_id_idx" ON "roles"("created_by_id");

-- CreateIndex
CREATE INDEX "roles_updated_by_id_idx" ON "roles"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "roles_organization_id_code_key" ON "roles"("organization_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "permissions_code_key" ON "permissions"("code");

-- CreateIndex
CREATE INDEX "user_roles_organization_id_idx" ON "user_roles"("organization_id");

-- CreateIndex
CREATE INDEX "user_roles_role_id_idx" ON "user_roles"("role_id");

-- CreateIndex
CREATE INDEX "user_roles_organization_unit_id_idx" ON "user_roles"("organization_unit_id");

-- CreateIndex
CREATE INDEX "user_roles_park_id_idx" ON "user_roles"("park_id");

-- CreateIndex
CREATE INDEX "user_roles_granted_by_id_idx" ON "user_roles"("granted_by_id");

-- CreateIndex
CREATE INDEX "user_roles_user_id_revoked_at_valid_until_idx" ON "user_roles"("user_id", "revoked_at", "valid_until");

-- CreateIndex
CREATE INDEX "role_permissions_permission_id_idx" ON "role_permissions"("permission_id");

-- CreateIndex
CREATE UNIQUE INDEX "role_permissions_role_id_permission_id_key" ON "role_permissions"("role_id", "permission_id");

-- CreateIndex
CREATE UNIQUE INDEX "drivers_driver_code_key" ON "drivers"("driver_code");

-- CreateIndex
CREATE UNIQUE INDEX "drivers_user_id_key" ON "drivers"("user_id");

-- CreateIndex
CREATE INDEX "drivers_organization_id_created_at_idx" ON "drivers"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "drivers_organization_id_organization_unit_id_idx" ON "drivers"("organization_id", "organization_unit_id");

-- CreateIndex
CREATE INDEX "drivers_organization_id_primary_park_id_idx" ON "drivers"("organization_id", "primary_park_id");

-- CreateIndex
CREATE INDEX "drivers_user_id_idx" ON "drivers"("user_id");

-- CreateIndex
CREATE INDEX "drivers_verified_by_id_idx" ON "drivers"("verified_by_id");

-- CreateIndex
CREATE INDEX "drivers_organization_id_registration_status_idx" ON "drivers"("organization_id", "registration_status");

-- CreateIndex
CREATE INDEX "drivers_organization_id_last_name_first_name_idx" ON "drivers"("organization_id", "last_name", "first_name");

-- CreateIndex
CREATE INDEX "drivers_created_by_id_idx" ON "drivers"("created_by_id");

-- CreateIndex
CREATE INDEX "drivers_updated_by_id_idx" ON "drivers"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "drivers_organization_id_id_key" ON "drivers"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "drivers_organization_id_membership_number_key" ON "drivers"("organization_id", "membership_number");

-- CreateIndex
CREATE INDEX "driver_contacts_organization_id_created_at_idx" ON "driver_contacts"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "driver_contacts_organization_id_driver_id_idx" ON "driver_contacts"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "driver_contacts_created_by_id_idx" ON "driver_contacts"("created_by_id");

-- CreateIndex
CREATE INDEX "driver_contacts_updated_by_id_idx" ON "driver_contacts"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "driver_contacts_organization_id_id_key" ON "driver_contacts"("organization_id", "id");

-- CreateIndex
CREATE INDEX "driver_documents_organization_id_created_at_idx" ON "driver_documents"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "driver_documents_organization_id_driver_id_idx" ON "driver_documents"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "driver_documents_verified_by_id_idx" ON "driver_documents"("verified_by_id");

-- CreateIndex
CREATE INDEX "driver_documents_uploaded_by_id_idx" ON "driver_documents"("uploaded_by_id");

-- CreateIndex
CREATE INDEX "driver_documents_organization_id_verificati_0fb37c2515fe" ON "driver_documents"("organization_id", "verification_status", "expiry_date");

-- CreateIndex
CREATE UNIQUE INDEX "driver_documents_organization_id_id_key" ON "driver_documents"("organization_id", "id");

-- CreateIndex
CREATE INDEX "driver_status_history_organization_id_created_at_idx" ON "driver_status_history"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "driver_status_history_changed_by_id_idx" ON "driver_status_history"("changed_by_id");

-- CreateIndex
CREATE INDEX "driver_status_history_organization_id_drive_fed898914931" ON "driver_status_history"("organization_id", "driver_id", "changed_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "driver_status_history_organization_id_id_key" ON "driver_status_history"("organization_id", "id");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_organization_id_created_at_idx" ON "driver_disciplinary_actions"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_organization_id_driver_id_idx" ON "driver_disciplinary_actions"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_issued_by_id_idx" ON "driver_disciplinary_actions"("issued_by_id");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_organization_id_park_id_idx" ON "driver_disciplinary_actions"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_organization_id_route_id_idx" ON "driver_disciplinary_actions"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "driver_disciplinary_actions_organization_id_incident_id_idx" ON "driver_disciplinary_actions"("organization_id", "incident_id");

-- CreateIndex
CREATE UNIQUE INDEX "driver_disciplinary_actions_organization_id_id_key" ON "driver_disciplinary_actions"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "conductors_conductor_code_key" ON "conductors"("conductor_code");

-- CreateIndex
CREATE UNIQUE INDEX "conductors_user_id_key" ON "conductors"("user_id");

-- CreateIndex
CREATE INDEX "conductors_organization_id_created_at_idx" ON "conductors"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "conductors_organization_id_primary_park_id_idx" ON "conductors"("organization_id", "primary_park_id");

-- CreateIndex
CREATE INDEX "conductors_user_id_idx" ON "conductors"("user_id");

-- CreateIndex
CREATE INDEX "conductors_created_by_id_idx" ON "conductors"("created_by_id");

-- CreateIndex
CREATE INDEX "conductors_updated_by_id_idx" ON "conductors"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "conductors_organization_id_id_key" ON "conductors"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "conductors_organization_id_membership_number_key" ON "conductors"("organization_id", "membership_number");

-- CreateIndex
CREATE INDEX "vehicle_owners_organization_id_created_at_idx" ON "vehicle_owners"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_owners_organization_id_driver_id_idx" ON "vehicle_owners"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "vehicle_owners_organization_id_name_idx" ON "vehicle_owners"("organization_id", "name");

-- CreateIndex
CREATE INDEX "vehicle_owners_created_by_id_idx" ON "vehicle_owners"("created_by_id");

-- CreateIndex
CREATE INDEX "vehicle_owners_updated_by_id_idx" ON "vehicle_owners"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_owners_organization_id_id_key" ON "vehicle_owners"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicles_vehicle_code_key" ON "vehicles"("vehicle_code");

-- CreateIndex
CREATE INDEX "vehicles_organization_id_created_at_idx" ON "vehicles"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicles_organization_id_primary_owner_id_idx" ON "vehicles"("organization_id", "primary_owner_id");

-- CreateIndex
CREATE INDEX "vehicles_organization_id_primary_park_id_idx" ON "vehicles"("organization_id", "primary_park_id");

-- CreateIndex
CREATE INDEX "vehicles_plate_number_idx" ON "vehicles"("plate_number");

-- CreateIndex
CREATE INDEX "vehicles_organization_id_registration_status_idx" ON "vehicles"("organization_id", "registration_status");

-- CreateIndex
CREATE INDEX "vehicles_created_by_id_idx" ON "vehicles"("created_by_id");

-- CreateIndex
CREATE INDEX "vehicles_updated_by_id_idx" ON "vehicles"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicles_organization_id_id_key" ON "vehicles"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicles_organization_id_plate_number_key" ON "vehicles"("organization_id", "plate_number");

-- CreateIndex
CREATE INDEX "vehicle_documents_organization_id_created_at_idx" ON "vehicle_documents"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_documents_organization_id_vehicle_id_idx" ON "vehicle_documents"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "vehicle_documents_verified_by_id_idx" ON "vehicle_documents"("verified_by_id");

-- CreateIndex
CREATE INDEX "vehicle_documents_uploaded_by_id_idx" ON "vehicle_documents"("uploaded_by_id");

-- CreateIndex
CREATE INDEX "vehicle_documents_organization_id_verificat_5bd9105bd684" ON "vehicle_documents"("organization_id", "verification_status", "expiry_date");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_documents_organization_id_id_key" ON "vehicle_documents"("organization_id", "id");

-- CreateIndex
CREATE INDEX "vehicle_ownership_history_organization_id_created_at_idx" ON "vehicle_ownership_history"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_ownership_history_organization_id_owner_id_idx" ON "vehicle_ownership_history"("organization_id", "owner_id");

-- CreateIndex
CREATE INDEX "vehicle_ownership_history_recorded_by_id_idx" ON "vehicle_ownership_history"("recorded_by_id");

-- CreateIndex
CREATE INDEX "vehicle_ownership_history_organization_id_v_a78661d86dd3" ON "vehicle_ownership_history"("organization_id", "vehicle_id", "start_date" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_ownership_history_organization_id_id_key" ON "vehicle_ownership_history"("organization_id", "id");

-- CreateIndex
CREATE INDEX "driver_vehicle_assignments_organization_id_created_at_idx" ON "driver_vehicle_assignments"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "driver_vehicle_assignments_assigned_by_id_idx" ON "driver_vehicle_assignments"("assigned_by_id");

-- CreateIndex
CREATE INDEX "driver_vehicle_assignments_organization_id__cadd3eb35d27" ON "driver_vehicle_assignments"("organization_id", "vehicle_id", "status", "end_at");

-- CreateIndex
CREATE INDEX "driver_vehicle_assignments_organization_id__a137ad50397e" ON "driver_vehicle_assignments"("organization_id", "driver_id", "start_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "driver_vehicle_assignments_organization_id_id_key" ON "driver_vehicle_assignments"("organization_id", "id");

-- CreateIndex
CREATE INDEX "vehicle_crew_assignments_organization_id_created_at_idx" ON "vehicle_crew_assignments"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_crew_assignments_organization_id_vehicle_id_idx" ON "vehicle_crew_assignments"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "vehicle_crew_assignments_organization_id_conductor_id_idx" ON "vehicle_crew_assignments"("organization_id", "conductor_id");

-- CreateIndex
CREATE INDEX "vehicle_crew_assignments_assigned_by_id_idx" ON "vehicle_crew_assignments"("assigned_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_crew_assignments_organization_id_id_key" ON "vehicle_crew_assignments"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "routes_route_code_key" ON "routes"("route_code");

-- CreateIndex
CREATE INDEX "routes_organization_id_created_at_idx" ON "routes"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "routes_organization_id_status_idx" ON "routes"("organization_id", "status");

-- CreateIndex
CREATE INDEX "routes_created_by_id_idx" ON "routes"("created_by_id");

-- CreateIndex
CREATE INDEX "routes_updated_by_id_idx" ON "routes"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "routes_organization_id_id_key" ON "routes"("organization_id", "id");

-- CreateIndex
CREATE INDEX "route_stops_organization_id_created_at_idx" ON "route_stops"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "route_stops_organization_id_route_id_idx" ON "route_stops"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "route_stops_created_by_id_idx" ON "route_stops"("created_by_id");

-- CreateIndex
CREATE INDEX "route_stops_updated_by_id_idx" ON "route_stops"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "route_stops_organization_id_id_key" ON "route_stops"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "route_stops_route_id_stop_order_key" ON "route_stops"("route_id", "stop_order");

-- CreateIndex
CREATE INDEX "park_routes_organization_id_created_at_idx" ON "park_routes"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "park_routes_organization_id_park_id_idx" ON "park_routes"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "park_routes_organization_id_route_id_idx" ON "park_routes"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "park_routes_created_by_id_idx" ON "park_routes"("created_by_id");

-- CreateIndex
CREATE INDEX "park_routes_updated_by_id_idx" ON "park_routes"("updated_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "park_routes_organization_id_id_key" ON "park_routes"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "park_routes_park_id_route_id_route_role_key" ON "park_routes"("park_id", "route_id", "route_role");

-- CreateIndex
CREATE INDEX "vehicle_route_assignments_organization_id_created_at_idx" ON "vehicle_route_assignments"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_route_assignments_organization_id_route_id_idx" ON "vehicle_route_assignments"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "vehicle_route_assignments_organization_id_park_id_idx" ON "vehicle_route_assignments"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "vehicle_route_assignments_assigned_by_id_idx" ON "vehicle_route_assignments"("assigned_by_id");

-- CreateIndex
CREATE INDEX "vehicle_route_assignments_organization_id_v_29342546d112" ON "vehicle_route_assignments"("organization_id", "vehicle_id", "status", "end_at");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_route_assignments_organization_id_id_key" ON "vehicle_route_assignments"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_qr_codes_public_token_hash_key" ON "vehicle_qr_codes"("public_token_hash");

-- CreateIndex
CREATE INDEX "vehicle_qr_codes_organization_id_created_at_idx" ON "vehicle_qr_codes"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "vehicle_qr_codes_issued_by_id_idx" ON "vehicle_qr_codes"("issued_by_id");

-- CreateIndex
CREATE INDEX "vehicle_qr_codes_organization_id_vehicle_id_status_idx" ON "vehicle_qr_codes"("organization_id", "vehicle_id", "status");

-- CreateIndex
CREATE INDEX "vehicle_qr_codes_expires_at_idx" ON "vehicle_qr_codes"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "vehicle_qr_codes_organization_id_id_key" ON "vehicle_qr_codes"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "passenger_sessions_session_token_hash_key" ON "passenger_sessions"("session_token_hash");

-- CreateIndex
CREATE INDEX "passenger_sessions_expires_at_idx" ON "passenger_sessions"("expires_at");

-- CreateIndex
CREATE INDEX "passenger_sessions_passenger_id_idx" ON "passenger_sessions"("passenger_id");

-- CreateIndex
CREATE UNIQUE INDEX "passengers_phone_key" ON "passengers"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "passengers_email_key" ON "passengers"("email");

-- CreateIndex
CREATE UNIQUE INDEX "passengers_external_auth_subject_key" ON "passengers"("external_auth_subject");

-- CreateIndex
CREATE UNIQUE INDEX "trusted_contacts_passenger_id_phone_key" ON "trusted_contacts"("passenger_id", "phone");

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_created_at_idx" ON "verification_scans"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_vehicle_id_idx" ON "verification_scans"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_qr_code_id_idx" ON "verification_scans"("organization_id", "qr_code_id");

-- CreateIndex
CREATE INDEX "verification_scans_session_id_idx" ON "verification_scans"("session_id");

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_driver_assignment_id_idx" ON "verification_scans"("organization_id", "driver_assignment_id");

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_route_assignment_id_idx" ON "verification_scans"("organization_id", "route_assignment_id");

-- CreateIndex
CREATE INDEX "verification_scans_vehicle_id_scanned_at_idx" ON "verification_scans"("vehicle_id", "scanned_at" DESC);

-- CreateIndex
CREATE INDEX "verification_scans_organization_id_scanned_at_idx" ON "verification_scans"("organization_id", "scanned_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "verification_scans_organization_id_id_key" ON "verification_scans"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "journeys_journey_code_key" ON "journeys"("journey_code");

-- CreateIndex
CREATE INDEX "journeys_organization_id_created_at_idx" ON "journeys"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "journeys_passenger_session_id_idx" ON "journeys"("passenger_session_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_vehicle_id_idx" ON "journeys"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_driver_id_idx" ON "journeys"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_driver_assignment_id_idx" ON "journeys"("organization_id", "driver_assignment_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_route_id_idx" ON "journeys"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_route_assignment_id_idx" ON "journeys"("organization_id", "route_assignment_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_boarding_park_id_idx" ON "journeys"("organization_id", "boarding_park_id");

-- CreateIndex
CREATE INDEX "journeys_organization_id_verification_scan_id_idx" ON "journeys"("organization_id", "verification_scan_id");

-- CreateIndex
CREATE INDEX "journeys_vehicle_id_boarded_at_idx" ON "journeys"("vehicle_id", "boarded_at" DESC);

-- CreateIndex
CREATE INDEX "journeys_organization_id_status_boarded_at_idx" ON "journeys"("organization_id", "status", "boarded_at" DESC);

-- CreateIndex
CREATE INDEX "journeys_passenger_id_boarded_at_idx" ON "journeys"("passenger_id", "boarded_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "journeys_organization_id_id_key" ON "journeys"("organization_id", "id");

-- CreateIndex
CREATE INDEX "journey_events_organization_id_created_at_idx" ON "journey_events"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "journey_events_organization_id_journey_id_event_time_idx" ON "journey_events"("organization_id", "journey_id", "event_time");

-- CreateIndex
CREATE UNIQUE INDEX "journey_events_organization_id_id_key" ON "journey_events"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "journey_shares_share_token_hash_key" ON "journey_shares"("share_token_hash");

-- CreateIndex
CREATE INDEX "journey_shares_organization_id_created_at_idx" ON "journey_shares"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "journey_shares_organization_id_journey_id_idx" ON "journey_shares"("organization_id", "journey_id");

-- CreateIndex
CREATE INDEX "journey_shares_trusted_contact_id_idx" ON "journey_shares"("trusted_contact_id");

-- CreateIndex
CREATE INDEX "journey_shares_expires_at_idx" ON "journey_shares"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "journey_shares_organization_id_id_key" ON "journey_shares"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "complaints_complaint_code_key" ON "complaints"("complaint_code");

-- CreateIndex
CREATE INDEX "complaints_organization_id_created_at_idx" ON "complaints"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "complaints_passenger_id_idx" ON "complaints"("passenger_id");

-- CreateIndex
CREATE INDEX "complaints_passenger_session_id_idx" ON "complaints"("passenger_session_id");

-- CreateIndex
CREATE INDEX "complaints_organization_id_journey_id_idx" ON "complaints"("organization_id", "journey_id");

-- CreateIndex
CREATE INDEX "complaints_organization_id_vehicle_id_idx" ON "complaints"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "complaints_organization_id_driver_id_idx" ON "complaints"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "complaints_organization_id_park_id_idx" ON "complaints"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "complaints_assigned_to_id_idx" ON "complaints"("assigned_to_id");

-- CreateIndex
CREATE INDEX "complaints_organization_id_status_reported_at_idx" ON "complaints"("organization_id", "status", "reported_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "complaints_organization_id_id_key" ON "complaints"("organization_id", "id");

-- CreateIndex
CREATE INDEX "complaint_updates_organization_id_created_at_idx" ON "complaint_updates"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "complaint_updates_updated_by_id_idx" ON "complaint_updates"("updated_by_id");

-- CreateIndex
CREATE INDEX "complaint_updates_author_passenger_id_idx" ON "complaint_updates"("author_passenger_id");

-- CreateIndex
CREATE INDEX "complaint_updates_author_session_id_idx" ON "complaint_updates"("author_session_id");

-- CreateIndex
CREATE INDEX "complaint_updates_organization_id_complaint_b9e5e20ed44d" ON "complaint_updates"("organization_id", "complaint_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "complaint_updates_organization_id_id_key" ON "complaint_updates"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "incidents_incident_code_key" ON "incidents"("incident_code");

-- CreateIndex
CREATE INDEX "incidents_organization_id_created_at_idx" ON "incidents"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "incidents_organization_id_journey_id_idx" ON "incidents"("organization_id", "journey_id");

-- CreateIndex
CREATE INDEX "incidents_organization_id_vehicle_id_idx" ON "incidents"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "incidents_organization_id_driver_id_idx" ON "incidents"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "incidents_organization_id_park_id_idx" ON "incidents"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "incidents_organization_id_route_id_idx" ON "incidents"("organization_id", "route_id");

-- CreateIndex
CREATE INDEX "incidents_reporter_passenger_id_idx" ON "incidents"("reporter_passenger_id");

-- CreateIndex
CREATE INDEX "incidents_reporter_session_id_idx" ON "incidents"("reporter_session_id");

-- CreateIndex
CREATE INDEX "incidents_reporter_user_id_idx" ON "incidents"("reporter_user_id");

-- CreateIndex
CREATE INDEX "incidents_assigned_to_id_idx" ON "incidents"("assigned_to_id");

-- CreateIndex
CREATE INDEX "incidents_organization_id_status_severity_reported_at_idx" ON "incidents"("organization_id", "status", "severity", "reported_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "incidents_organization_id_id_key" ON "incidents"("organization_id", "id");

-- CreateIndex
CREATE INDEX "incident_evidence_organization_id_created_at_idx" ON "incident_evidence"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "incident_evidence_organization_id_incident_id_idx" ON "incident_evidence"("organization_id", "incident_id");

-- CreateIndex
CREATE INDEX "incident_evidence_uploaded_by_id_idx" ON "incident_evidence"("uploaded_by_id");

-- CreateIndex
CREATE INDEX "incident_evidence_uploader_passenger_id_idx" ON "incident_evidence"("uploader_passenger_id");

-- CreateIndex
CREATE INDEX "incident_evidence_uploader_session_id_idx" ON "incident_evidence"("uploader_session_id");

-- CreateIndex
CREATE UNIQUE INDEX "incident_evidence_organization_id_id_key" ON "incident_evidence"("organization_id", "id");

-- CreateIndex
CREATE INDEX "incident_updates_organization_id_created_at_idx" ON "incident_updates"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "incident_updates_updated_by_id_idx" ON "incident_updates"("updated_by_id");

-- CreateIndex
CREATE INDEX "incident_updates_author_passenger_id_idx" ON "incident_updates"("author_passenger_id");

-- CreateIndex
CREATE INDEX "incident_updates_author_session_id_idx" ON "incident_updates"("author_session_id");

-- CreateIndex
CREATE INDEX "incident_updates_organization_id_incident_id_created_at_idx" ON "incident_updates"("organization_id", "incident_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "incident_updates_organization_id_id_key" ON "incident_updates"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "lost_property_cases_case_code_key" ON "lost_property_cases"("case_code");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_created_at_idx" ON "lost_property_cases"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_journey_id_idx" ON "lost_property_cases"("organization_id", "journey_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_vehicle_id_idx" ON "lost_property_cases"("organization_id", "vehicle_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_driver_id_idx" ON "lost_property_cases"("organization_id", "driver_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_park_id_idx" ON "lost_property_cases"("organization_id", "park_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_passenger_id_idx" ON "lost_property_cases"("passenger_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_passenger_session_id_idx" ON "lost_property_cases"("passenger_session_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_assigned_to_id_idx" ON "lost_property_cases"("assigned_to_id");

-- CreateIndex
CREATE INDEX "lost_property_cases_organization_id_status_reported_at_idx" ON "lost_property_cases"("organization_id", "status", "reported_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "lost_property_cases_organization_id_id_key" ON "lost_property_cases"("organization_id", "id");

-- CreateIndex
CREATE INDEX "lost_property_updates_organization_id_created_at_idx" ON "lost_property_updates"("organization_id", "created_at");

-- CreateIndex
CREATE INDEX "lost_property_updates_updated_by_id_idx" ON "lost_property_updates"("updated_by_id");

-- CreateIndex
CREATE INDEX "lost_property_updates_author_passenger_id_idx" ON "lost_property_updates"("author_passenger_id");

-- CreateIndex
CREATE INDEX "lost_property_updates_author_session_id_idx" ON "lost_property_updates"("author_session_id");

-- CreateIndex
CREATE INDEX "lost_property_updates_organization_id_lost__aa3b475bfd31" ON "lost_property_updates"("organization_id", "lost_property_case_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "lost_property_updates_organization_id_id_key" ON "lost_property_updates"("organization_id", "id");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_idempotency_key_key" ON "notifications"("idempotency_key");

-- CreateIndex
CREATE INDEX "notifications_organization_id_idx" ON "notifications"("organization_id");

-- CreateIndex
CREATE INDEX "notifications_status_scheduled_at_next_attempt_at_idx" ON "notifications"("status", "scheduled_at", "next_attempt_at");

-- CreateIndex
CREATE INDEX "notifications_recipient_user_id_read_at_created_at_idx" ON "notifications"("recipient_user_id", "read_at", "created_at" DESC);

-- CreateIndex
CREATE INDEX "notifications_recipient_passenger_id_read_at_created_at_idx" ON "notifications"("recipient_passenger_id", "read_at", "created_at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_actor_user_id_idx" ON "audit_logs"("actor_user_id");

-- CreateIndex
CREATE INDEX "audit_logs_organization_id_created_at_idx" ON "audit_logs"("organization_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "audit_logs_organization_id_entity_type_enti_8c11e43bc46b" ON "audit_logs"("organization_id", "entity_type", "entity_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "security_events_passenger_id_idx" ON "security_events"("passenger_id");

-- CreateIndex
CREATE INDEX "security_events_passenger_session_id_idx" ON "security_events"("passenger_session_id");

-- CreateIndex
CREATE INDEX "security_events_organization_id_event_type_created_at_idx" ON "security_events"("organization_id", "event_type", "created_at" DESC);

-- CreateIndex
CREATE INDEX "security_events_user_id_created_at_idx" ON "security_events"("user_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "system_settings_key_key" ON "system_settings"("key");

-- CreateIndex
CREATE INDEX "system_settings_updated_by_id_idx" ON "system_settings"("updated_by_id");

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organizations" ADD CONSTRAINT "organizations_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_settings" ADD CONSTRAINT "organization_settings_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "administrative_areas" ADD CONSTRAINT "administrative_areas_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "administrative_areas"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "administrative_areas" ADD CONSTRAINT "administrative_areas_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "administrative_areas" ADD CONSTRAINT "administrative_areas_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_units" ADD CONSTRAINT "organization_units_organization_id_parent_unit_id_fkey" FOREIGN KEY ("organization_id", "parent_unit_id") REFERENCES "organization_units"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_units" ADD CONSTRAINT "organization_units_administrative_area_id_fkey" FOREIGN KEY ("administrative_area_id") REFERENCES "administrative_areas"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_units" ADD CONSTRAINT "organization_units_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_units" ADD CONSTRAINT "organization_units_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "organization_units" ADD CONSTRAINT "organization_units_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_organization_id_organization_unit_id_fkey" FOREIGN KEY ("organization_id", "organization_unit_id") REFERENCES "organization_units"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_administrative_area_id_fkey" FOREIGN KEY ("administrative_area_id") REFERENCES "administrative_areas"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_manager_user_id_fkey" FOREIGN KEY ("manager_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "parks" ADD CONSTRAINT "parks_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "roles" ADD CONSTRAINT "roles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "roles" ADD CONSTRAINT "roles_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "roles" ADD CONSTRAINT "roles_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_organization_unit_id_fkey" FOREIGN KEY ("organization_unit_id") REFERENCES "organization_units"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_park_id_fkey" FOREIGN KEY ("park_id") REFERENCES "parks"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "user_roles" ADD CONSTRAINT "user_roles_granted_by_id_fkey" FOREIGN KEY ("granted_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_role_id_fkey" FOREIGN KEY ("role_id") REFERENCES "roles"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_permission_id_fkey" FOREIGN KEY ("permission_id") REFERENCES "permissions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_organization_id_organization_unit_id_fkey" FOREIGN KEY ("organization_id", "organization_unit_id") REFERENCES "organization_units"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_organization_id_primary_park_id_fkey" FOREIGN KEY ("organization_id", "primary_park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_verified_by_id_fkey" FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "drivers" ADD CONSTRAINT "drivers_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_contacts" ADD CONSTRAINT "driver_contacts_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_contacts" ADD CONSTRAINT "driver_contacts_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_contacts" ADD CONSTRAINT "driver_contacts_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_contacts" ADD CONSTRAINT "driver_contacts_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_verified_by_id_fkey" FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_status_history" ADD CONSTRAINT "driver_status_history_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_status_history" ADD CONSTRAINT "driver_status_history_changed_by_id_fkey" FOREIGN KEY ("changed_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_status_history" ADD CONSTRAINT "driver_status_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_issued_by_id_fkey" FOREIGN KEY ("issued_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_organization_id_incident_id_fkey" FOREIGN KEY ("organization_id", "incident_id") REFERENCES "incidents"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_disciplinary_actions" ADD CONSTRAINT "driver_disciplinary_actions_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "conductors" ADD CONSTRAINT "conductors_organization_id_primary_park_id_fkey" FOREIGN KEY ("organization_id", "primary_park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "conductors" ADD CONSTRAINT "conductors_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "conductors" ADD CONSTRAINT "conductors_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "conductors" ADD CONSTRAINT "conductors_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "conductors" ADD CONSTRAINT "conductors_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_owners" ADD CONSTRAINT "vehicle_owners_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_owners" ADD CONSTRAINT "vehicle_owners_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_owners" ADD CONSTRAINT "vehicle_owners_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_owners" ADD CONSTRAINT "vehicle_owners_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_organization_id_primary_owner_id_fkey" FOREIGN KEY ("organization_id", "primary_owner_id") REFERENCES "vehicle_owners"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_organization_id_primary_park_id_fkey" FOREIGN KEY ("organization_id", "primary_park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_documents" ADD CONSTRAINT "vehicle_documents_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_documents" ADD CONSTRAINT "vehicle_documents_verified_by_id_fkey" FOREIGN KEY ("verified_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_documents" ADD CONSTRAINT "vehicle_documents_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_documents" ADD CONSTRAINT "vehicle_documents_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_ownership_history" ADD CONSTRAINT "vehicle_ownership_history_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_ownership_history" ADD CONSTRAINT "vehicle_ownership_history_organization_id_owner_id_fkey" FOREIGN KEY ("organization_id", "owner_id") REFERENCES "vehicle_owners"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_ownership_history" ADD CONSTRAINT "vehicle_ownership_history_recorded_by_id_fkey" FOREIGN KEY ("recorded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_ownership_history" ADD CONSTRAINT "vehicle_ownership_history_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_vehicle_assignments" ADD CONSTRAINT "driver_vehicle_assignments_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_vehicle_assignments" ADD CONSTRAINT "driver_vehicle_assignments_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_vehicle_assignments" ADD CONSTRAINT "driver_vehicle_assignments_assigned_by_id_fkey" FOREIGN KEY ("assigned_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "driver_vehicle_assignments" ADD CONSTRAINT "driver_vehicle_assignments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_crew_assignments" ADD CONSTRAINT "vehicle_crew_assignments_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_crew_assignments" ADD CONSTRAINT "vehicle_crew_assignments_organization_id_conductor_id_fkey" FOREIGN KEY ("organization_id", "conductor_id") REFERENCES "conductors"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_crew_assignments" ADD CONSTRAINT "vehicle_crew_assignments_assigned_by_id_fkey" FOREIGN KEY ("assigned_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_crew_assignments" ADD CONSTRAINT "vehicle_crew_assignments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "routes" ADD CONSTRAINT "routes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "routes" ADD CONSTRAINT "routes_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "routes" ADD CONSTRAINT "routes_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "route_stops" ADD CONSTRAINT "route_stops_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "route_stops" ADD CONSTRAINT "route_stops_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "route_stops" ADD CONSTRAINT "route_stops_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "route_stops" ADD CONSTRAINT "route_stops_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "park_routes" ADD CONSTRAINT "park_routes_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "park_routes" ADD CONSTRAINT "park_routes_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "park_routes" ADD CONSTRAINT "park_routes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "park_routes" ADD CONSTRAINT "park_routes_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "park_routes" ADD CONSTRAINT "park_routes_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_route_assignments" ADD CONSTRAINT "vehicle_route_assignments_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_route_assignments" ADD CONSTRAINT "vehicle_route_assignments_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_route_assignments" ADD CONSTRAINT "vehicle_route_assignments_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_route_assignments" ADD CONSTRAINT "vehicle_route_assignments_assigned_by_id_fkey" FOREIGN KEY ("assigned_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_route_assignments" ADD CONSTRAINT "vehicle_route_assignments_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_qr_codes" ADD CONSTRAINT "vehicle_qr_codes_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_qr_codes" ADD CONSTRAINT "vehicle_qr_codes_issued_by_id_fkey" FOREIGN KEY ("issued_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "vehicle_qr_codes" ADD CONSTRAINT "vehicle_qr_codes_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "passenger_sessions" ADD CONSTRAINT "passenger_sessions_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "trusted_contacts" ADD CONSTRAINT "trusted_contacts_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_organization_id_qr_code_id_fkey" FOREIGN KEY ("organization_id", "qr_code_id") REFERENCES "vehicle_qr_codes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_organization_id_driver_assignment_id_fkey" FOREIGN KEY ("organization_id", "driver_assignment_id") REFERENCES "driver_vehicle_assignments"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_organization_id_route_assignment_id_fkey" FOREIGN KEY ("organization_id", "route_assignment_id") REFERENCES "vehicle_route_assignments"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "verification_scans" ADD CONSTRAINT "verification_scans_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_passenger_session_id_fkey" FOREIGN KEY ("passenger_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_driver_assignment_id_fkey" FOREIGN KEY ("organization_id", "driver_assignment_id") REFERENCES "driver_vehicle_assignments"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_route_assignment_id_fkey" FOREIGN KEY ("organization_id", "route_assignment_id") REFERENCES "vehicle_route_assignments"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_boarding_park_id_fkey" FOREIGN KEY ("organization_id", "boarding_park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_verification_scan_id_fkey" FOREIGN KEY ("organization_id", "verification_scan_id") REFERENCES "verification_scans"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journeys" ADD CONSTRAINT "journeys_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journey_events" ADD CONSTRAINT "journey_events_organization_id_journey_id_fkey" FOREIGN KEY ("organization_id", "journey_id") REFERENCES "journeys"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journey_events" ADD CONSTRAINT "journey_events_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journey_shares" ADD CONSTRAINT "journey_shares_organization_id_journey_id_fkey" FOREIGN KEY ("organization_id", "journey_id") REFERENCES "journeys"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journey_shares" ADD CONSTRAINT "journey_shares_trusted_contact_id_fkey" FOREIGN KEY ("trusted_contact_id") REFERENCES "trusted_contacts"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "journey_shares" ADD CONSTRAINT "journey_shares_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_passenger_session_id_fkey" FOREIGN KEY ("passenger_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_organization_id_journey_id_fkey" FOREIGN KEY ("organization_id", "journey_id") REFERENCES "journeys"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_assigned_to_id_fkey" FOREIGN KEY ("assigned_to_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaint_updates" ADD CONSTRAINT "complaint_updates_organization_id_complaint_id_fkey" FOREIGN KEY ("organization_id", "complaint_id") REFERENCES "complaints"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaint_updates" ADD CONSTRAINT "complaint_updates_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaint_updates" ADD CONSTRAINT "complaint_updates_author_passenger_id_fkey" FOREIGN KEY ("author_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaint_updates" ADD CONSTRAINT "complaint_updates_author_session_id_fkey" FOREIGN KEY ("author_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "complaint_updates" ADD CONSTRAINT "complaint_updates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_journey_id_fkey" FOREIGN KEY ("organization_id", "journey_id") REFERENCES "journeys"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_route_id_fkey" FOREIGN KEY ("organization_id", "route_id") REFERENCES "routes"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_reporter_passenger_id_fkey" FOREIGN KEY ("reporter_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_reporter_session_id_fkey" FOREIGN KEY ("reporter_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_reporter_user_id_fkey" FOREIGN KEY ("reporter_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_assigned_to_id_fkey" FOREIGN KEY ("assigned_to_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incidents" ADD CONSTRAINT "incidents_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_evidence" ADD CONSTRAINT "incident_evidence_organization_id_incident_id_fkey" FOREIGN KEY ("organization_id", "incident_id") REFERENCES "incidents"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_evidence" ADD CONSTRAINT "incident_evidence_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_evidence" ADD CONSTRAINT "incident_evidence_uploader_passenger_id_fkey" FOREIGN KEY ("uploader_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_evidence" ADD CONSTRAINT "incident_evidence_uploader_session_id_fkey" FOREIGN KEY ("uploader_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_evidence" ADD CONSTRAINT "incident_evidence_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_updates" ADD CONSTRAINT "incident_updates_organization_id_incident_id_fkey" FOREIGN KEY ("organization_id", "incident_id") REFERENCES "incidents"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_updates" ADD CONSTRAINT "incident_updates_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_updates" ADD CONSTRAINT "incident_updates_author_passenger_id_fkey" FOREIGN KEY ("author_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_updates" ADD CONSTRAINT "incident_updates_author_session_id_fkey" FOREIGN KEY ("author_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "incident_updates" ADD CONSTRAINT "incident_updates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_organization_id_journey_id_fkey" FOREIGN KEY ("organization_id", "journey_id") REFERENCES "journeys"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_organization_id_vehicle_id_fkey" FOREIGN KEY ("organization_id", "vehicle_id") REFERENCES "vehicles"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_organization_id_driver_id_fkey" FOREIGN KEY ("organization_id", "driver_id") REFERENCES "drivers"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_organization_id_park_id_fkey" FOREIGN KEY ("organization_id", "park_id") REFERENCES "parks"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_passenger_session_id_fkey" FOREIGN KEY ("passenger_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_assigned_to_id_fkey" FOREIGN KEY ("assigned_to_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_cases" ADD CONSTRAINT "lost_property_cases_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_updates" ADD CONSTRAINT "lost_property_updates_organization_id_lost_property_case_i_fkey" FOREIGN KEY ("organization_id", "lost_property_case_id") REFERENCES "lost_property_cases"("organization_id", "id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_updates" ADD CONSTRAINT "lost_property_updates_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_updates" ADD CONSTRAINT "lost_property_updates_author_passenger_id_fkey" FOREIGN KEY ("author_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_updates" ADD CONSTRAINT "lost_property_updates_author_session_id_fkey" FOREIGN KEY ("author_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "lost_property_updates" ADD CONSTRAINT "lost_property_updates_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_user_id_fkey" FOREIGN KEY ("recipient_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_recipient_passenger_id_fkey" FOREIGN KEY ("recipient_passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_actor_user_id_fkey" FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_organization_id_fkey" FOREIGN KEY ("organization_id") REFERENCES "organizations"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_passenger_id_fkey" FOREIGN KEY ("passenger_id") REFERENCES "passengers"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_passenger_session_id_fkey" FOREIGN KEY ("passenger_session_id") REFERENCES "passenger_sessions"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE "system_settings" ADD CONSTRAINT "system_settings_updated_by_id_fkey" FOREIGN KEY ("updated_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE RESTRICT;
