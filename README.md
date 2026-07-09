# Salesforce Metadata-Driven User Provisioning

A Salesforce proof of concept that automates user provisioning based on Job Code using Custom Metadata Types and Platform Events.

## Features

- Automatic Role Assignment
- Automatic Permission Set Assignment
- Automatic Public Group Assignment
- Automatic Revocation on Job Code Change
- Bulkified Apex Implementation
- Platform Event Driven Architecture
- Metadata Driven Configuration

## Technologies

- Salesforce Apex
- Platform Events
- Custom Metadata Types
- Permission Sets
- Public Groups
- User Roles

## Components

### Apex Classes

- JobCodeConfig
- JobCodeConfigService
- UserTriggerHandler
- UserProvisioningEventHandler

### Apex Triggers

- UserTrigger
- UserProvisioningEventTrigger

### Custom Metadata

- Job_Code_Setting__mdt
- Job_Code_Permission_Set__mdt
- Job_Code_Public_Group__mdt

### Platform Event

- User_Provisioning_Event__e

## Workflow

1. User is Created or Updated
2. User Trigger publishes a Platform Event
3. Event Handler reads Job Code configuration
4. Assigns Role
5. Assigns Permission Sets
6. Assigns Public Groups
7. Revokes obsolete access on Job Code change

## Author

Karankishore
Salesforce Developer
