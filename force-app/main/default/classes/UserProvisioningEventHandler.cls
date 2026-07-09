public with sharing class UserProvisioningEventHandler {

    public static void handle(List<User_Provisioning_Event__e> events) {

        if (events == null || events.isEmpty()) {
            return;
        }

        //==================================================
        // Read Configurations
        //==================================================

        Map<Decimal, JobCodeConfig> configMap = new Map<Decimal, JobCodeConfig>();

        Set<String> roleDeveloperNames = new Set<String>();
        Set<String> permissionSetNames = new Set<String>();
        Set<String> publicGroupNames = new Set<String>();
        Set<Decimal> newJobCodes = new Set<Decimal>();
        Set<Decimal> oldJobCodes = new Set<Decimal>();

        Set<Id> userIds = new Set<Id>();

        for (User_Provisioning_Event__e eventObj : events) {

            userIds.add((Id)eventObj.User_Id__c);

            JobCodeConfig config =
                JobCodeConfigService.getConfig(eventObj.Job_Code__c);

            if (config == null) {
                continue;
            }

            configMap.put(eventObj.Job_Code__c, config);

            if (String.isNotBlank(config.roleDeveloperName)) {
                roleDeveloperNames.add(config.roleDeveloperName);
            }
            if(eventObj.Job_Code__c != null){
                newJobCodes.add(eventObj.Job_Code__c);
            }
            permissionSetNames.addAll(config.permissionSets);
            publicGroupNames.addAll(config.publicGroups);

            // ---- FIX ----
            // The old Permission Sets / Public Groups need to be in
            // these same lookup sets too, otherwise the revoke logic
            // further down can never resolve permissionSetMap.get(...)
            // or groupMap.get(...) for the OLD job code, and the
            // delete branch silently never fires.
            if(eventObj.Previous_Job_Code__c != null){
                oldJobCodes.add(eventObj.Previous_Job_Code__c);

                JobCodeConfig oldConfigForLookup =
                    JobCodeConfigService.getConfig(eventObj.Previous_Job_Code__c);

                if (oldConfigForLookup != null) {
                    permissionSetNames.addAll(oldConfigForLookup.permissionSets);
                    publicGroupNames.addAll(oldConfigForLookup.publicGroups);
                }
            }
            // ---- END FIX ----
        }

        //==================================================
        // Query Roles
        //==================================================

        Map<String, UserRole> roleMap = new Map<String, UserRole>();

        if (!roleDeveloperNames.isEmpty()) {

            for (UserRole role : [
                SELECT Id, DeveloperName
                FROM UserRole
                WHERE DeveloperName IN :roleDeveloperNames
            ]) {
                roleMap.put(role.DeveloperName, role);
            }
        }

        //==================================================
        // Query Permission Sets
        //==================================================

        Map<String, PermissionSet> permissionSetMap =
            new Map<String, PermissionSet>();

        if (!permissionSetNames.isEmpty()) {

            for (PermissionSet ps : [
                SELECT Id, Name
                FROM PermissionSet
                WHERE Name IN :permissionSetNames
            ]) {
                permissionSetMap.put(ps.Name, ps);
            }
        }

        //==================================================
        // Query Public Groups
        //==================================================

        Map<String, Group> groupMap = new Map<String, Group>();

        if (!publicGroupNames.isEmpty()) {

            for (Group grp : [
                SELECT Id, DeveloperName FROM Group WHERE Type='Regular' AND DeveloperName IN :publicGroupNames]) {
                groupMap.put(grp.DeveloperName, grp);
            }
        }
        Map<Decimal,JobCodeConfig> newConfigs = new Map<Decimal,JobCodeConfig>();
        Map<Decimal,JobCodeConfig> oldConfigs = new Map<Decimal,JobCodeConfig>();

        for(Decimal jc : newJobCodes){
            newConfigs.put(jc, JobCodeConfigService.getConfig(jc));
        }

        for(Decimal jc : oldJobCodes){
            oldConfigs.put(jc, JobCodeConfigService.getConfig(jc));
        }
        //==================================================
        // Existing Permission Set Assignments
        //==================================================

        Map<String, Id> existingPSAssignments = new Map<String, Id>();
        for (PermissionSetAssignment psa : [SELECT Id, AssigneeId, PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId IN :userIds]) {
            existingPSAssignments.put(psa.AssigneeId + '-' + psa.PermissionSetId,psa.Id);
        }
        //==================================================
        // Existing Group Members
        //==================================================

        Map<String, Id> existingGroupMembers = new Map<String, Id>();

        for (GroupMember gm : [SELECT Id, UserOrGroupId, GroupId FROM GroupMember WHERE UserOrGroupId IN :userIds]) {
            existingGroupMembers.put(gm.UserOrGroupId + '-' + gm.GroupId,gm.Id);
        }
        //==================================================
        // Prepare DML
        //==================================================

        List<User> usersToUpdate = new List<User>();
        List<PermissionSetAssignment> psaToInsert = new List<PermissionSetAssignment>();
        List<PermissionSetAssignment> psaDelete = new List<PermissionSetAssignment>();

        List<GroupMember> groupMembersToInsert = new List<GroupMember>();
        List<GroupMember> groupDelete = new List<GroupMember>();

        for (User_Provisioning_Event__e eventObj : events) {
            JobCodeConfig config = configMap.get(eventObj.Job_Code__c);
            if (config == null) {
                continue;
            }
            JobCodeConfig newCfg = newConfigs.get(eventObj.Job_Code__c);
            JobCodeConfig oldCfg = oldConfigs.get(eventObj.Previous_Job_Code__c);
            //------------------------------------------------
            // Role
            //------------------------------------------------

            UserRole role = roleMap.get(config.roleDeveloperName);
            if (role != null) {
                usersToUpdate.add(
                    new User(Id = (Id)eventObj.User_Id__c,UserRoleId = role.Id));
            }

            //------------------------------------------------
            // Permission Sets
            //------------------------------------------------

            for (String psName : config.permissionSets) {
                PermissionSet ps = permissionSetMap.get(psName);
                if (ps == null) {
                    continue;
                }
                String key = eventObj.User_Id__c + '-' + ps.Id;
                if (!existingPSAssignments.containsKey(key)) {
                    psaToInsert.add(new PermissionSetAssignment(AssigneeId=(Id)eventObj.User_Id__c,PermissionSetId=ps.Id));
                }
                if(oldCfg != null){
                    for(String psToDelete : oldCfg.permissionSets){
                        if(newCfg == null || !newCfg.permissionSets.contains(psToDelete)){
                            PermissionSet permissionSet = permissionSetMap.get(psToDelete);
                            if (permissionSet != null) {
                                String deleteKey =eventObj.User_Id__c + '-' + permissionSet.Id;
                                Id psaId = existingPSAssignments.get(deleteKey);
                                if (psaId != null) {
                                    psaDelete.add(new PermissionSetAssignment(Id = psaId));
                                }
                            }      
                        }
                    }
                }
            }
            //------------------------------------------------
            // Public Groups
            //------------------------------------------------

            for (String groupName : config.publicGroups) {
                Group grp = groupMap.get(groupName);
                if (grp == null) {
                    continue;
                }
                String key = eventObj.User_Id__c + '-' + grp.Id;
                if (!existingGroupMembers.containsKey(key)) {
                    groupMembersToInsert.add(new GroupMember(GroupId=grp.Id,UserOrGroupId=(Id)eventObj.User_Id__c));
                }
                if(oldCfg != null){
                    for(String grpToDelete : oldCfg.publicGroups){
                        if(newCfg == null || !newCfg.publicGroups.contains(grpToDelete)){
                            Group groupObj = groupMap.get(grpToDelete);
                            if (groupObj != null) {
                                String deleteKey =eventObj.User_Id__c + '-' + groupObj.Id;    
                                Id groupMemberId =existingGroupMembers.get(deleteKey);
                                if (groupMemberId != null) {
                                    groupDelete.add(new GroupMember(Id = groupMemberId));
                                }
                            }
                        }
                    }
                }

            }
        }
        //==================================================
        // DML
        //==================================================
        if(!psaDelete.isEmpty()){
            Database.delete(psaDelete,false);
        }
        if(!groupDelete.isEmpty()){
            Database.delete(groupDelete,false);
        }
        if (!usersToUpdate.isEmpty()) {
            Database.update(usersToUpdate, false);
        }
        if (!psaToInsert.isEmpty()) {
            Database.insert(psaToInsert, false);
        }
        if (!groupMembersToInsert.isEmpty()) {
            Database.insert(groupMembersToInsert, false);
        }
    }
}