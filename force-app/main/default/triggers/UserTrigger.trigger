trigger UserTrigger on User (after insert, after update) {
    UserTriggerHandler.handle(Trigger.new,Trigger.oldMap,Trigger.isInsert,Trigger.isUpdate);
}