trigger UserProvisioningEventTrigger on User_Provisioning_Event__e(after insert){
    UserProvisioningEventHandler.handle(Trigger.New);
}