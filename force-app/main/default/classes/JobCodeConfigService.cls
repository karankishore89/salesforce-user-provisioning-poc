public with sharing class JobCodeConfigService {
    public static JobCodeConfig getConfig(Decimal jobCode) {
        JobCodeConfig config = new JobCodeConfig();
        Job_Code_Setting__mdt setting = [SELECT Job_Code__c,Role_Developer_Name__c,Is_Active__c FROM Job_Code_Setting__mdt WHERE Job_Code__c = :jobCode AND Is_Active__c = true LIMIT 1];
        config.jobCode = setting.Job_Code__c;
        config.roleDeveloperName = setting.Role_Developer_Name__c;
        for(Job_Code_Permission_Set__mdt ps :[SELECT Permission_API_Name__c FROM Job_Code_Permission_Set__mdt WHERE Job_Code_Setting__c = :jobCode]){
            config.permissionSets.add(ps.Permission_API_Name__c);
        }
        for(Job_Code_Public_Group__mdt grp :[SELECT Group__c FROM Job_Code_Public_Group__mdt WHERE Job_Code__c = :jobCode]){
            config.publicGroups.add(grp.Group__c);
        }
        return config;
    }
}