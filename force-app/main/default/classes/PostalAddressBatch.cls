/****************************************************************************************
 * Name             : PostalAddressBatch
 * Created By       : Vicky Weissman
 * Created Date     : April 2019
 * Purpose          : Update contact mailing addresses, household billing addreses, and 
 *                    household's current postal addresses  
 * 
 * ASSUMPTIONS
 * 
 * ABBREVIATIONS
 * H = Household, C = Contact, Addr = Postal Address
 *  
 * NOTES
 * 
 *****************************************************************************************/

global class PostalAddressBatch implements Database.Batchable<sObject>, Schedulable { 
    
    // SOQL to get the addresses that need to be copied to the contacts and households
    public string queryAddrs; 
    
    /**************************************************************************************************
      Constructors
    **************************************************************************************************/
    // was going to use in testing
    global PostalAddressBatch(){}
    
    // scheduled job calls this constructor and then executes the batch job 
    global PostalAddressBatch(String query) {
        
        // init the query
        this.queryAddrs = query;
    
    } // end constructor taking query as input
    
    /**************************************************************************************************
      Execute (scheduler)
    **************************************************************************************************/
    global void execute(SchedulableContext SC) {            
        // get addresses that are valid and coming into effect
        string addrFlds = 'Street__c, City__c, State_Province__c, Zip_Postal_Code__c, Country__c';
        string keyFlds = 'id, Name, Household__c, Start_Date__c, End_Date__c, Repeat_Annually__c, ' + addrFlds;
        
        string valid = '(Invalid__c = false) AND ((Errors__c = null) OR (Errors__c = \'\'))';        
        string inRange = '(Start_Date__c <= TODAY) AND ((End_Date__c >= TODAY) OR (Repeat_Annually__c = True))';
        
        // we shouldn't pull addresses that are already the current one for their households
        // but the query is failing. Maybe rethink how we're recording the current address on postal addrs?
        //string isUpdate = 'id != :Household__r.Current_Postal_Address__r.id';
        //queryAddrs = 'SELECT '+keyFlds+' FROM Postal_Address__c WHERE '+valid+' AND '+inRange+' AND '+isUpdate;
         
        // for now, only update address that "went live" in last 5 days
        // this will make the code less robust (what happens when Bob accidentally cancels the job?)
        // but it'll be more efficient
        string newlyLive = '((Start_Date__c = LAST_N_DAYS:5) OR (Start_Date__c = TODAY))';
        queryAddrs = 'SELECT '+keyFlds+' FROM Postal_Address__c WHERE '+valid+' AND '+inRange+ ' AND '+newlyLive;
        
        // run batch code
        PostalAddressBatch job = new PostalAddressBatch(queryAddrs);
        database.executeBatch(job);
    } // end execute (scheduler)   
    
    /**************************************************************************************************
	 Start (batch)
	**************************************************************************************************/
    global database.Querylocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(queryAddrs);
    } // end start (batch)
    
   /**************************************************************************************************
      Execute (batch)
    **************************************************************************************************/
    global void execute(Database.BatchableContext BC, list<sobject> scope){ 
        // make a mapping of household IDs to their address updates
        map<id, Postal_Address__c> m_HID_addrs = new map<id, Postal_Address__c>();
        
        for (sobject s: scope) {
            
            Postal_Address__c addr = (Postal_Address__c) s; // query pulls postal addresses
                
            boolean b_skip = skipUpdate(addr);
            if (!b_skip) {
                m_HID_addrs.put(addr.Household__c, addr);    
            }                      
        }
        
        // get the household info
        list<account> l_households = [Select id, BillingAddress, Current_Postal_Address__c
                                      From account
                                      Where id in: m_HID_addrs.keySet()];
        
        // update the households, contacts will update automatically afterwards       
        if ((l_households != null) && (l_households.size() > 0)) {
            
            for (account h: l_households){
                // get the household's potentially new address
                Postal_Address__c addrForH = m_HID_addrs.get(h.id);
                
                if (addrForH != null) {
                    if (addrForH.id != h.Current_Postal_Address__c) {
                       // we're not overridding a manual update or 
                       // "updating" a billing address with the values it already has
                        
                        h.BillingStreet = addrForH.Street__c;
                        h.BillingCity = addrForH.City__c;
                        h.BillingState = addrForH.State_Province__c;
                        h.BillingPostalCode = addrForH.Zip_Postal_Code__c;
                        h.BillingCountry = addrForH.Country__c;
                        h.Current_Postal_Address__c = addrForH.id;
                    }
                }
                
            } //  end loop through households 
            
            // update the org
            database.update(l_households, false);
        } // end check that we have households to update
         
    } // end execute (batch)
    
    /**************************************************************************************************
      Finish (batch)
    **************************************************************************************************/
    global void finish(Database.BatchableContext BC){
        // nothing to do
    } // end finish method          
    
     
   /****************************************************************************************************
    * 						 HELPER METHODS
    *****************************************************************************************************/ 
   /****************************************************************************************************
    * skipUpdate
    * 
    * Return false if and only if the address is valid, error-free, and 
    * the address' date range includes today. This could be because the start and end dates "bracket" 
    * today or because the address' dates repeat annually and one of their repeats "bracket" today
    * 
    * Note: Called in PostalAddressHandler. We should probably move this to a utility class
    *****************************************************************************************************/
    public static boolean skipUpdate(Postal_Address__c addr) {

        date startDate = addr.Start_Date__c;
        date endDate = addr.End_Date__c;
        date todaysDate = date.today(); 
        
		// handle the easy cases first
		string errors = addr.Errors__c;
        if (addr.Invalid__c || !string.isBlank(errors)) {
            return true;
        }
		
        if ((startDate <= todaysDate) && ((endDate == null) || (endDate >= todaysDate))) {
            return false;
        }
        
        // handle the annual repeats
        boolean b_skip = true;
        if ((startDate <= todaysDate) && (addr.Repeat_Annually__c)) {
            
            // move forward until we might be "bracketing" today
            // note: endDate isn't null. If it were then we'd be covered by the easy case above
            
            // get years close to each other
            integer estimatedYrsBetween = (todaysDate.year() - endDate.year())-2; 
            if (estimatedYrsBetween > 0) {
                startDate = startDate.addYears(estimatedYrsBetween);
                endDate = endDate.addYears(estimatedYrsBetween);                        
            }
            
            while (endDate < todaysDate) {
                startDate = startDate.addYears(1);
                endDate = endDate.addYears(1);
            }
            
            // if we're "bracketing" today, set b_skip to false 
            if (startDate <= todaysDate) {
                b_skip = false;
            }
        }
        
        return b_skip;        
    } // end skipUpdate
        
} // end PostalAddressBatch class