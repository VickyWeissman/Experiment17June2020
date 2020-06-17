/****************************************************************************************
 * Name             : PostalAddressHandler.apxc
 * Created By       : Vicky Weissman
 * Created Date     : April 2019
 * Called By        : PostalAddressTrigger.apxt
 * Purpose          : Update the addresses on contacts and households
 *                    Verify the address (e.g., one address per contact per date)  
 * 
 * ASSUMPTIONS
 * 
 * ABBREVIATIONS
 * H = Household, C = Contact, Addr = Postal Address
 *
 * NOTES
 *****************************************************************************************/

public class PostalAddressHandler {
       
   /****************************************************************************************************
    * insertAddrs
    * For each postal address being inserted, check that the dates don't overlap
    * If they overlap, fill-in the error log on the relevant addresses
    *****************************************************************************************************/     
    public static boolean insertAddrs(List<Postal_Address__c> l_newAddrs){
        
        // get the household IDs
        set<id> s_HIDs = new set<id>();
        for (Postal_Address__c addr: l_newAddrs) {
            s_HIDs.add(addr.Household__c);
        }
        
        // get the relevant addresses from the org, omit none
        list<Postal_Address__c> l_orgAddrs = getOrgAddrs(s_HIDs, new set<id>());
        
        // log errors on each new address whose dates overlap with another's
        boolean result = invalidateOverlaps(l_newAddrs, l_orgAddrs);
        
        return true;
    } // end insertAddrs method


   /****************************************************************************************************
    * updateAddrs
    * For each postal address being updated,check that the dates don't overlap
    * If they overlap, fill-in the error log on the relevant addresses
    *****************************************************************************************************/ 
    public static boolean updateAddrs(List<Postal_Address__c> l_addrs, map<id, Postal_Address__c> newMap, map<id, Postal_Address__c> oldMap){
       
        // get the addrs IDs and household IDs
        set<id> s_AddrIDs = new set<id>();
        set<id> s_HIDs = new set<id>();
        
        for (Postal_Address__c addr: l_addrs) {
            s_AddrIDs.add(addr.Id);
            s_HIDs.add(addr.Household__c);
        }
        
        // get the relevant addresses from the org, omit the ones that we're updating
        list<Postal_Address__c> l_orgAddrs = getOrgAddrs(s_HIDs, s_AddrIDs);
        
        // log errors on each changing address whose new dates overlap with another's
        boolean result = invalidateOverlaps(l_addrs, l_orgAddrs);
    
        return true;
    } // end updateAddrs
    
   /****************************************************************************************************
    * updateHousehold
    * If a new address applies today, then update the billing and mailing addresses
    * Update the "current postal address" on the household too
    * 
    * This is redundant with batch code. Need to redesign (utility method?)
    *****************************************************************************************************/ 
    public static boolean updateHouseholds(List<Postal_Address__c> l_addrs){
        
        // get the addresses that should be applied today
        map<id, Postal_Address__c> m_HID_addr = new map<id,Postal_Address__c>(); 
        
        for (Postal_Address__c addr: l_addrs){
            if (!PostalAddressBatch.skipUpdate(addr)){
                m_HID_addr.put(addr.Household__c, addr);
            }
        }
        
        // get the corresponding household information
 		list<account> l_households = [Select id, BillingAddress
                                      From account
                                      Where id in: m_HID_addr.keySet()];
        
        // update the household
        if ((l_households != null) &&  (l_households.size() > 0)) {
            for (account h: l_households) {
                
                Postal_Address__c addr = m_HID_addr.get(h.id);
                
                if (addr != null) {
                    h.BillingStreet = addr.Street__c;
                    h.BillingCity = addr.City__c;  
                    h.BillingState = addr.State_Province__c;
                    h.BillingPostalCode = addr.Zip_Postal_Code__c;
                    h.BillingCountry = addr.Country__c;
                    h.Current_Postal_Address__c = addr.id;
                }
            } // end loop through households
            
            // update the org
            database.update(l_households, false); // if this fails, batch job should pick it up. 
        } // end check that there are households to update

        return true;
    } // end updateHousehold
 
   /****************************************************************************************************
    * 						 HELPER METHODS
    *****************************************************************************************************/ 
    
    /****************************************************************************************************
    * getOrgAddrs
    * Input: set of household IDs and set of address IDs
    * Output: a list of the valid household's addresses minus the ones in the second param
    * 
    * Note: This is mostly to minimize cut-and-paste between inserts and updates
    *****************************************************************************************************/
    private static list<Postal_Address__c> getOrgAddrs(set<id> s_HIDs, set<id> s_AddrIDs) {
        
        // get the valid addrs for the households in the org, omit the ones in the input
        list<Postal_Address__c> l_orgAddrs = [Select id, Name, Household__c, Errors__c,
                                                     Start_Date__c, End_Date__c, Repeat_Annually__c
                                              From Postal_Address__c
                                              Where (Household__c in: s_HIDs) AND (id not in: s_AddrIDs) AND 
                                              Invalid__c = false AND (Errors__c = null OR Errors__c = '')];
        
        if ((l_orgAddrs == null) || (l_orgAddrs.size()) < 1) {
            l_orgAddrs = new list<Postal_Address__c>();
        }
        
        return l_orgAddrs;
    } // end getOrgAddrs method
    
   /****************************************************************************************************
    * invalidateOverlaps
    * Input: a set of addresses being evaluated, a set of "fixed" addresses
    * Function: if an address in the evaluation list overlaps with a fixed one or with another in the list, 
    *           mark the address as invalid and provide a comprehensive reason
    * 
    * Note:
    * - I want to tell the user about all conflicts so they don't fix one, find another, fix that, ...
    * - Some of the checks are redundant. Example: we check if addresses have the same household here
    *   and in gotOverlap. This should be cleaned-up
    * - Method is public so I can run it directly from Test
    *****************************************************************************************************/   
     public static boolean invalidateOverlaps(list<Postal_Address__c> l_addrs, list<Postal_Address__c> l_orgAddrs) {

        // I'm going to do nested for loops across all address. This isn't efficient. 
        // If I have time, I'll convert the address lists to maps, segmenting them by household 
        // (i.e., map<id, list<Postal_Address__c>>). Then loops will be for addresses of the same household
                
         for (Postal_Address__c addr: l_addrs) {
             // reset error log. 
             // Need to do this on all addresses before looking for errors
             // Otherwise, we'll delete a new error message when we've found overlaps in l_addrs
             addr.Errors__c = '';
         }
         
         for (Postal_Address__c addr: l_addrs) {      
            // compare date ranges with other addresses
            for (Postal_Address__c oldAddr: l_orgAddrs) {
                if (addr.Household__c == oldAddr.Household__c) {
                    
                    // same household, check dates
                    boolean b_gotOverlap = gotOverlap(addr, oldAddr);
                    
                    if (b_gotOverlap){
                        addr.Errors__c += ' Dates overlap with '+oldAddr.Name+'.'; // should put in link to oldAddr
                    }
                } 
            } // end loop through old addresses
            
            // compare date ranges with other changing addresses
            // should think about most efficient way to do this
            for (Postal_Address__c addr2: l_addrs) {
                //system.debug('comparing: '+addr+' at index '+l_addrs.indexOf(addr)+' household: '+addr.Household__c);
                //system.debug('with: '+addr2+' at index '+l_addrs.indexOf(addr2)+' household: '+addr2.Household__c);
                
                if ((l_addrs.indexOf(addr) < l_addrs.indexOf(addr2)) && 
                    (addr.Household__c == addr2.Household__c)) {
                        
                        // different list elements with same household, check dates
                        boolean b_gotOverlap = gotOverlap(addr, addr2);
                        
                        if (b_gotOverlap){
                            // record errors on both addresses
                            if (addr2.Name != null) {
                                addr.Errors__c += ' Dates overlap with '+addr2.Name+'.'; // should put in link to addr
                            } else {
                                addr.Errors__c += ' Dates overlap with another address. See list on household record for details.';
                            }
                          
                            if (addr.Name != null) {
                                addr2.Errors__c += ' Dates overlap with '+addr.Name+'.'; // should put in link to addr
                            } else {
                                addr2.Errors__c += ' Dates overlap with another address. See list on household record for details.';
                            }
                         }
                    } // end if 2 elements are at the same household
            } // end inner loop through changing addresses
            
        } // end outter loop through changing addresses
         
         return true; 
     } // end invalidateOverlaps method
    
    /****************************************************************************************************
    * gotOverlap
    * Input: 2 postal addresses
    * Output: True if the 2 addresses might overlap. False otherwise.
    * 
    * Example: address 1 starts on April 1, 2019 and has no end date.
    *          address 2 starts on June 1, 2019 and ends on Sept 1, 2019
    *          gotOverlap returns true because there might be an overlap 
    * 
    * The logic to handle repeating annually is dodgy. Test thoroughly, or maybe remove feature :(
    * Made method public to facilitate testing.
    *****************************************************************************************************/
    public static boolean gotOverlap(Postal_Address__c addr1, Postal_Address__c addr2){
        
        // handle easy cases first
        if (addr1.Household__c != addr2.Household__c) {
            // addresses are for different households
            return false;
        }
        
        string error1 = addr1.Errors__c;
        string error2 = addr2.Errors__c;
        if (addr1.Invalid__c || addr2.Invalid__c || !string.isBlank(error1) || !string.isBlank(error2)) {
            // at least 1 address is not in effect, so overlaps aren't a problem. 
            return false;
        }
        
        // compare date ranges
        boolean b_gotOverlap = true;

        // get the date ranges
        date start1 = addr1.Start_Date__c;
        date end1 = addr1.End_Date__c;
        
        date start2 = addr2.Start_Date__c;
        date end2 = addr2.End_Date__c;
        
        // no overlap in addresses if one starts after the other ends
        if ((end1 != null) && (start2 != null) && (end1 < start2)) {
          
            if (addr1.Repeat_Annually__c) {
                if (end2 != null) {
                    // repeat addr1 dates every year until it "passes" start2
                    
                    // get years close to each other
                    integer estimatedYrsBetween = (start2.year() - end1.year())-2; 
                    if (estimatedYrsBetween > 0) {
                        start1 = start1.addYears(estimatedYrsBetween);
                        end1 = end1.addYears(estimatedYrsBetween);                        
                    }
                    
                    while (end1 < start2) {                        
                        start1 = start1.addYears(1);
                        end1 = end1.addYears(1);
                    } 
                    
                    if (start1 > end2) {
                        // addr1 "leap frogs" over addr2
                        b_gotOverlap = false;  
                    }
                }
            } else {
                b_gotOverlap = false;  
            }
          
        } else if ((end2 != null) && (start1 != null) && (end2 < start1)) {
            
            if (addr2.Repeat_Annually__c) {
                if (end1 != null) {
                    // repeat addr2 dates every year until it "passes" start1
                    
                    // get years close to each other
                    integer estimatedYrsBetween = (start1.year() - end2.year())-2; 
                    if (estimatedYrsBetween > 0) {
                        start2 = start2.addYears(estimatedYrsBetween);
                        end2 = end2.addYears(estimatedYrsBetween);                        
                    }
                    
                    while (end2 < start1) {
                        system.debug('addr2: '+addr2.id+', end2: '+end2+', start1: '+start1);
                        
                        start2 = start2.addYears(1);
                        end2 = end2.addYears(1);
                    } 
                    
                    if (start2 > end1) {
                        // addr2 "leap frogs" over addr1
                        b_gotOverlap = false;  
                    }
                }
            } else {
                b_gotOverlap = false;  
            }           
        } 
        
        return b_gotOverlap;
    } // end gotOverlap method

} // end PostalAddressHandler class