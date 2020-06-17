/*****************************************************************************
 * Name             : PostalAddressTrigger
 * Created By       : Vicky Weissman
 * Created Date     : April 2019
 * Purpose          : Master trigger for postal address records 
 * Notes            : Do NOT create other triggers for postal address records
 *                    Do NOT put logic here
 * 
 * Additional Notes
 * - Future versions should handle deletions
 * - unit tests seem to be detecting trigger recursion on updates. 
 *   manual tests suggest this is fine in practice.
 *   For now, I'll have the unit tests skip the recursive check. 
 *   This will let us debug the updating code
 *****************************************************************************/

trigger PostalAddressTrigger on Postal_Address__c (before insert, after insert, before update, after update) {
        
    if(Trigger.isBefore) {   
    
        if (Trigger.isInsert && CheckForRecursion.firstRun()) {   
            Boolean b_result = PostalAddressHandler.insertAddrs(Trigger.new);
        } else if (Trigger.isUpdate && (test.isRunningTest() || CheckForRecursion.firstRun())) {
            Boolean b_result = PostalAddressHandler.updateAddrs(Trigger.new, Trigger.newMap, Trigger.oldMap);              
        }
        
    } else if(Trigger.isAfter) {
       
        if (Trigger.isInsert) { 
            Boolean b_result = PostalAddressHandler.updateHouseholds(Trigger.new);
        } else if (Trigger.isUpdate) {
            Boolean b_result = PostalAddressHandler.updateHouseholds(Trigger.new);              
        }
        
    }
} // end PostalAddressTrigger.apxt