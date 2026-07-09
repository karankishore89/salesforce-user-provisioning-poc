public with sharing class UserTriggerHandler {

    public static void handle(List<User> newUsers,Map<Id,User> oldMap,Boolean isInsert,Boolean isUpdate){
        List<User_Provisioning_Event__e> events = new List<User_Provisioning_Event__e>();
        for(User u : newUsers){
            if(u.Job_Code__c == null){
                continue;
            }
            User_Provisioning_Event__e eventObj = new User_Provisioning_Event__e();
            eventObj.User_Id__c = u.Id;
            eventObj.Job_Code__c = u.Job_Code__c;
            eventObj.Operation__c = isInsert ? 'INSERT' : 'UPDATE';
            if (isUpdate) {
                User oldUser = oldMap.get(u.Id);
                if (oldUser.Job_Code__c == u.Job_Code__c) {
                    continue;
                }
                eventObj.Previous_Job_Code__c = oldUser.Job_Code__c;
            } 
            events.add(eventObj);
        }

        if(!events.isEmpty()){
            Database.SaveResult[] sr = EventBus.publish(events);
            System.debug(sr);
        }
    }
}