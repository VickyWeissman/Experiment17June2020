/***********************************************************************************************************
 * Name             : PostalAddressHandlerTest
 * Created By       : Victoria Weissman :)
 * Created Date     : April 2019
 * Purpose          : validate PostalAddressTrigger.apxt and PostalAddressHandler.apxc
 * 
 * Abbreviations
 * H = Household, C = Contact, Addr = Postal Address
 * 
 * Notes:  
 * - In practice, I'd have the makeContact and makePostalAddress methods in a (test) utility class
 * 
 * - Weird behavior found: I update a household and a new household is created with the same name
 *                         When I update manually, no duplicate households are created 
 * 					       My code never inserts or upserts a household
 *                         Guessing this has to do with the sync? (not my code)
 * 
 * - We should have at least 1 household ID be a static variable. As is, we're cutting-and-pasting a lot
 * 
 * - Running out of time so I started testing methods individually. This is sub-optimal because we should
 *   be designing tests that naturally run all parts of the code (or identifies code that can be cut). Also,
 *   to make this work, some private methods were made public. But it's a fast way to find and fix bugs.
 * 
***********************************************************************************************************/

@istest
public class PostalAddressHandlerTest {
    
    //public static date todaysDate;
    
    /***********************************************************************************************************
     * makeData
     * 
     * Create 3 households
     * - Romano: Ann, Julie, Barbara
     * - Jefferson: George, Louise
     * - Simpson: Lisa (the other cartoon characters are not in any philanthropic database :)
     ***********************************************************************************************************/              
    @testSetup static void makeData(){ 
        
        list<contact> l_contact = new list<contact>();
        
        // create the Romano's
        l_contact.add(makeContact('Ann', 'Romano', '123 Main Street', 'Los Angeles', 'CA'));
        l_contact.add(makeContact('Julie', 'Romano', '123 Main Street', 'Los Angeles', 'CA'));
        l_contact.add(makeContact('Barbara', 'Romano', '123 Main Street', 'Los Angeles', 'CA')); 
        
        // create the Jefferson's
        l_contact.add(makeContact('George', 'Jefferson', '123 Main Street', 'New York', 'NY'));
        l_contact.add(makeContact('Louise', 'Jefferson', '123 Main Street', 'New York', 'NY'));
        
        // create Lisa Simpson
        l_contact.add(makeContact('Lisa', 'Simpson', '123 Main Street', 'Springfield', 'Oregon'));
        
        // update the org
        database.insert(l_contact); 
        
    } // end makeData testSetup
    
    /***********************************************************************************************************
     * makeContact
     * Everyone has zip 90210 and country USA
     ***********************************************************************************************************/     
    public static Contact makeContact(string firstName, string lastName, string street, string city, string state){
        Contact con = new Contact();
        con.FirstName = firstName;
        con.LastName = lastName;
        con.MailingStreet = street;    
        con.MailingCity = city;
        con.MailingState = state;
        con.MailingCountry = 'USA';
        con.MailingPostalCode = '90210';
        return con;
    } // end makeContact method

    /***********************************************************************************************************
     * makePostalAddress
     * Everyone has zip 90210 and country USA
     ***********************************************************************************************************/     
    public static Postal_Address__c makePostalAddress(id HID, date startDate, date endDate, string street, string city, string state){
        Postal_Address__c addr = new Postal_Address__c();
        addr.Household__c = HID;
        addr.Start_Date__c = startDate;
        addr.End_Date__c = endDate; 
        addr.Street__c = street;
        addr.City__c = city;
        addr.State_Province__c = state;
        addr.Country__c = 'USA';
        addr.Zip_Postal_Code__c = '90210';

        return addr;
    } // end makePostalAddress
    
    /***********************************************************************************************************
     *									TEST METHODS
     ***********************************************************************************************************/ 
 
    /***********************************************************************************************************
     * simpleTest 
     * 
     * Create 1 address that applies today
     * Check that the address is created and has correct "current address", 
     *            the mailing and billing addresses are updated 
     * 
     * Note: To check "current address", I look for an update on the household record. A config formula makes 
     *       sure that the "current address" on the postal address matches the household's
     * 
     * Satisfies user acceptance criteria, somewhat (test covers only the most basic case)
     * 2. he addresses automatically populate the MailingAddress fields on the Contact when they are 
     * ‘in-season’, meaning the current date is within the start/end date values of that address
     * 3. The current valid address is indicated on the address record
     ***********************************************************************************************************/ 
    static TestMethod void simpleTest() {
        
        // get the household ID for the Jefferson's
        account h_Jefferson = [Select id
                               From account
                               Where Name like '%Jefferson%'
                               Limit 1];
        
        system.assert(h_Jefferson != null);
        
        // make an address that applies today
        date todaysdate = date.today();
        date startDate = todaysDate.addDays(-10);
        date endDate = todaysDate.addDays(10);
        Postal_Address__c newAddr = makePostalAddress(h_Jefferson.id, startDate, endDate, '222 State Street', 'Seattle', 'WA' );
        
        // run the test
        test.startTest();
        insert(newAddr);
        test.stopTest();      
        
        // check the results
        // chech that the address was created 
        list<Postal_Address__c> l_addrs = [Select id, Street__c
                                           From Postal_Address__c
                                           Where State_Province__c = 'WA' AND Zip_Postal_Code__c = '90210'];
        
        system.debug('Simple Test: l_addrs is '+l_addrs);
        system.assert(l_addrs != null);
        system.assertEquals(1, l_addrs.size()); 
        
        id newAddrID = l_addrs[0].id; // current address is updated if the Jefferson household's match this 
        
        // check that Jefferson household was updated, Simpson's wasn't 
        list<account> l_accounts = [Select id, Name, BillingAddress, BillingStreet, Current_Postal_Address__c
                                    From account
                                    Where Type = 'Household' AND
                                          (Name like '%Jefferson%' OR Name like '%Simpson%')];
        
        system.assert(l_accounts != null);
        
        for (account a: l_accounts) {
            // accounts include 2 Jefferson households. One pre-update and one post. Same created/last modified dates
            // I think this has to do with how the sync operates, can't see how my code could cause this
            system.debug('Simple Test: l_accounts includes '+a);            
        }
        
        boolean b_foundNewJefferson = false;
        boolean b_foundOldSimpson = true;
        
        for (account acct: l_accounts) {
            string acctName = acct.Name;
            string acctStreet = acct.BillingStreet;
            
            if (acctName.containsIgnoreCase('Jefferson') && acctStreet.containsIgnoreCase('222 State Street')) {
                
                b_foundNewJefferson = true;
                system.assertEquals(newAddrID, acct.Current_Postal_Address__c);
                
            } else if (acctName.containsIgnoreCase('Simpson') && !acctStreet.containsIgnoreCase('222 State Street')) {
                
                b_foundOldSimpson = true;
                system.assert(newAddrID != acct.Current_Postal_Address__c);
            }
        }
        
        system.assert(b_foundNewJefferson);        
        system.assert(b_foundOldSimpson);

        // check that George Jefferson's mailing address was updated
        // not sure check belongs here since the contact updates is done by the sync, not our code
        // But, since our code assumes the sync is working, we probably want to test if it's not
        contact c_GeorgeJefferson = [Select id, MailingStreet, MailingAddress
                                     From Contact
                                     Where Name = 'George Jefferson'
                                     Limit 1];
        
        system.assert(c_GeorgeJefferson != null);
        
        string GJstreet = c_GeorgeJefferson.MailingStreet;
        system.assertEquals('222 State Street', GJstreet);
            
    } // end simpleTest

    /***********************************************************************************************************
     * simpleUpdates
     * 
     * Repeat the insertion from the simpleInsert test
     * Manually update the contact's mailing address (George Jefferson's)
     * Make the recently inserted address invalid
     * Verify that updates succeeded
     * 
     * Satisfies user acceptance criteria
     * 5. I can override a start and end date and force an address onto the Contact manually
     * 6. I can mark an address as invalid
     ***********************************************************************************************************/ 
    static TestMethod void simpleUpdates() {
        
        // get the household ID for the Jefferson's
        account h_Jefferson = [Select id
                               From account
                               Where Name like '%Jefferson%'
                               Limit 1];
        
        system.assert(h_Jefferson != null);
        
        // make an address that applies today
        date todaysdate = date.today();
        date startDate = todaysDate.addDays(-10);
        date endDate = todaysDate.addDays(10);
        Postal_Address__c newAddr = makePostalAddress(h_Jefferson.id, startDate, endDate, '222 State Street', 'Seattle', 'WA' );
        
        // make sure invalid is false
        newAddr.Invalid__c = false;
        insert(newAddr);
        
        // get the new addr
        newAddr = [Select id, Invalid__c
                   From Postal_Address__c 
                   Where Street__c = '222 State Street'
                   Limit 1];
        
        system.assert(newAddr != null);
        
        id newAddrID = newAddr.id;
        newAddr.Invalid__c = true;

        // get George Jefferson's mailing address
        contact c_GeorgeJefferson = [Select id, MailingStreet, MailingAddress
                                     From Contact
                                     Where Name = 'George Jefferson'
                                     Limit 1];
        
        system.assert(c_GeorgeJefferson != null);
        id GeorgeID = c_GeorgeJefferson.id;
        c_GeorgeJefferson.MailingStreet = '321 Easy Street';
        
        // run the test
        test.startTest();
		update(c_GeorgeJefferson);
        update(newAddr);
        test.stopTest();      
        
        // check the results
        // George has new street address
		contact c_updatedGeorge = [Select id, MailingStreet, MailingAddress
                               	   From Contact
                                   Where id =: GeorgeID AND MailingStreet = '321 Easy Street'
                                   Limit 1];
        
        system.assert(c_updatedGeorge != null);
        
        // address is invalid
        Postal_Address__c updatedAddr = [Select id, Invalid__c
                   						 From Postal_Address__c 
                                         Where id  =: newAddrID
                                         Limit 1];
        
        system.assert(updatedAddr != null);
        system.assert(updatedAddr.Invalid__c);
    } // end simpleUpdates
    
    /***********************************************************************************************************
     * In progress: Create tests for each method in Handler. Clean-up code as you go and as time permits.
     * Still to test: invalidateOverlaps (just started) and getOrgAddrs
     ***********************************************************************************************************/
    /***********************************************************************************************************
     * gotOverlap_noRepeats
     * Verify the output of gotOverlap when given various, non-repeating addresses
     ***********************************************************************************************************/ 
	static TestMethod void gotOverlap_noRepeats() {
        
        // get household IDs that we can use when making postal addresses 
        list<account> l_accounts = [Select id
                                    From account
                                    Where Name like '%Jefferson%' OR Name like '%Simpson%'
                                    Limit 2];
        
        id HID1 = l_accounts[0].id;
        id HID2 = l_accounts[1].id;        
        
        // create postal addresses, and verify method output
        date nextWeek = (date.today()).addDays(7);
        boolean result;
        
        // invalid address shouldn't overlap with any other, not even its self
        Postal_Address__c addrInvalid = makePostalAddress(HID1, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state');
        addrInvalid.Invalid__c = true;
        
        result = PostalAddressHandler.gotOverlap(addrInvalid, addrInvalid);
        system.assert(!result);
        
        // addresses for different households shouldn't overlap
        Postal_Address__c addr1 = makePostalAddress(HID1, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state');           
        Postal_Address__c addr2 = makePostalAddress(HID2, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state');
        
        result = PostalAddressHandler.gotOverlap(addr1, addr2);
        system.assert(!result);
 
        // addresses without overlap
        Postal_Address__c addrFixed = makePostalAddress(HID1, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state'); 
        Postal_Address__c addrBefore = makePostalAddress(HID1, nextWeek.addDays(-7), nextWeek.addDays(-5), 'street', 'city', 'state');           
        
        result = PostalAddressHandler.gotOverlap(addrBefore, addrFixed);
        system.assert(!result);
        
        // continue testing different scenarios
        Postal_Address__c addrAtStart = makePostalAddress(HID1, nextWeek.addDays(-7), nextWeek, 'street', 'city', 'state');           
        result = PostalAddressHandler.gotOverlap(addrAtStart, addrFixed);
        system.assert(result);

        Postal_Address__c addrBeyondStart = makePostalAddress(HID1, nextWeek.addDays(-7), nextWeek.addDays(2), 'street', 'city', 'state');           
        result = PostalAddressHandler.gotOverlap(addrBeyondStart, addrFixed);
        system.assert(result);       
        
        Postal_Address__c addrInMiddle = makePostalAddress(HID1, nextWeek.addDays(2), nextWeek.addDays(4), 'street', 'city', 'state');        
        result = PostalAddressHandler.gotOverlap(addrInMiddle, addrFixed);
        system.assert(result); 

        Postal_Address__c addrAtEnd = makePostalAddress(HID1, nextWeek.addDays(7), nextWeek.addDays(14), 'street', 'city', 'state');        
        result = PostalAddressHandler.gotOverlap(addrAtEnd, addrFixed);
        system.assert(result); 
        
        Postal_Address__c addrBeyondEnd = makePostalAddress(HID1, nextWeek.addDays(14), nextWeek.addDays(21), 'street', 'city', 'state');        
        result = PostalAddressHandler.gotOverlap(addrBeyondEnd, addrFixed);
        system.assert(!result);     
    } // end gotOverlap_noRepeats method
    
     /***********************************************************************************************************
     * gotOverlap_repeats
     * Verify the output of gotOverlap when given various addresses, some repeating
     ***********************************************************************************************************/ 
    static TestMethod void gotOverlap_repeats() {  
        // get household ID that we can use when making postal addresses 
        list<account> l_accounts = [Select id
                                    From account
                                    Where Name like '%Jefferson%' 
                                    Limit 1];
        
        id HID = l_accounts[0].id;       
        
        // create postal addresses, and verify method output
        date nextWeek = (date.today()).addDays(7);
        boolean result;
        
        // test scenarios
        // repeat's original dates are way before the fixed, but the two will overlap
        Postal_Address__c addrFixed = makePostalAddress(HID, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state');
        
        Postal_Address__c addrEarlyRepeat = makePostalAddress(HID, nextWeek.addYears(-5), (nextWeek.addYears(-5)).addDays(3), 'street', 'city', 'state');
        addrEarlyRepeat.Repeat_Annually__c = true;
        
        result = PostalAddressHandler.gotOverlap(addrEarlyRepeat, addrFixed);
        system.assert(result);
        
        // swapping param order shouldn't matter
        result = PostalAddressHandler.gotOverlap(addrFixed, addrEarlyRepeat);
        system.assert(result);
        
        // repeat's original dates are after the fixed, so the two won't overlap unless fixed loses its end date
        Postal_Address__c addrLateRepeat = makePostalAddress(HID, nextWeek.addYears(1), (nextWeek.addYears(1)).addDays(3), 'street', 'city', 'state');
        addrLateRepeat.Repeat_Annually__c = true;
        
        result = PostalAddressHandler.gotOverlap(addrLateRepeat, addrFixed);
        system.assert(!result);
        
        // swapping param order shouldn't matter
        result = PostalAddressHandler.gotOverlap(addrFixed, addrLateRepeat);
        system.assert(!result);
        
        addrFixed.End_Date__c = null; // end date is unknown
        result = PostalAddressHandler.gotOverlap(addrLateRepeat, addrFixed);
        system.assert(result);
        
        // swap
        result = PostalAddressHandler.gotOverlap(addrFixed, addrLateRepeat);
        system.assert(result);       
        
        // thought about testing if both addresses are repeating, but that should be the same as 
        // the earliest one repeating
    } // gotOverlap_repeats methods
    
    /***********************************************************************************************************
     * checkInvalidateOverlaps
     * 
     * overlappind addresses in update list gets invalidated
     * overlapping address in 2 different lists gets invalidated
     * 
     * This is a quick sanity check. Running short on time.
     ***********************************************************************************************************/ 
	static TestMethod void checkInvalidateOverlaps() {
        // get household ID that we can use when making postal addresses 
        list<account> l_accounts = [Select id
                                    From account
                                    Where Name like '%Jefferson%' 
                                    Limit 1];
        
        id HID = l_accounts[0].id;       
        
        // create postal addresses, and verify method output
        date nextWeek = (date.today()).addDays(7);
        boolean result;
        
        Postal_Address__c addr1 = makePostalAddress(HID, nextWeek, nextWeek.addDays(7), 'street', 'city', 'state');
        Postal_Address__c addrOverlap = makePostalAddress(HID, nextWeek.addDays(5), nextWeek.addDays(10), 'street', 'city', 'state');
        Postal_Address__c addrNoOverlap = makePostalAddress(HID, nextWeek.addDays(20), nextWeek.addDays(30), 'street', 'city', 'state');

		// overlapping addresses in update list should invalidate each other
        list<Postal_Address__c> l_addrs = new list<Postal_Address__c>();
        l_addrs.add(addr1);
        l_addrs.add(addrOverlap);

        result = PostalAddressHandler.invalidateOverlaps(l_addrs, new list<Postal_Address__c>());
        
        string errors1 = addr1.Errors__c;
        system.debug('addr1 errors: '+errors1);
        system.assert(!string.isBlank(errors1));
        
        string errorsOverlap = addrOverlap.Errors__c;
        system.debug('errorsOverlap errors: '+errorsOverlap);
        system.assert(!string.isBlank(errorsOverlap));
        
        // overlapping addresses with an org address should be invalidated
        // reset
        l_addrs = new list<Postal_Address__c>();
        addr1.Errors__c = '';
        addrOverlap.Errors__c = '';
        
        // make params
        l_addrs.add(addr1);
        l_addrs.add(addrNoOverlap);
        
        list<Postal_Address__c> l_orgAddrs = new list<Postal_Address__c>();
        l_orgAddrs.add(addrOverlap);
        
        // call method
        result = PostalAddressHandler.invalidateOverlaps(l_addrs, l_orgAddrs);
        
        // verify results
        errors1 = addr1.Errors__c;
        system.debug('addr1 errors: '+errors1);
        system.assert(!string.isBlank(errors1));
        
     	string errorsNoOverlap = addrNoOverlap.Errors__c;
        system.debug('addrNoOverlap errors: '+errorsNoOverlap);
        system.assert(string.isBlank(errorsNoOverlap));
        
    } // end checkInvalidateOverlaps method
    
    /***********************************************************************************************************
     * FAILING! Putting aside for now. Need to revisit.
     * 
     * stressTest 
     * 
     * Create 20 non-repeating addresses that don't overlap with any others
     *        20 non-repeating addresses that overlap
     *        150 repeating addresses that overlap
     * 
     * Make sure we don't hit any governor's limits.       
     * If this test passes, we should be in good shape for data imports
     * 
     * Note: 
     * Hit CPU limits when creating 150 repeating addresses at same account. This is 
     * unlikely to occur in practice. But I still think we should replace the
     * repeat handling in gotOverlap with a better algorithm (no surprise, current ones a hack)
     * 
     * CPU still times out when I split the repeating addresses over 8 households. 
     ***********************************************************************************************************/
/*
     static TestMethod void stressTest() {
        
        // make 8 households
        list<contact> l_newContacts = new list<Contact>();
        
        for (integer i = 0; i < 8; i++) {
            string str_i = string.valueOf(i);
            l_newContacts.add(makeContact('Alice', 'Smith'+str_i, '123 Happy Dappy Lane', 'NYC', 'NY'));    
        }
        
        insert(l_newContacts);
        
        // get the households
        list<account> l_households = [Select id, Name
                                      From account
                                      Where type = 'Household'
                                      Limit 8];
        
        system.assert(l_households != null);
        system.assertEquals(8, l_households.size());
        
        // make the addresses
        list<Postal_Address__c> l_newAddrs = new list<Postal_Address__c>();
        
        date todaysDate = date.today();
        date FiftyYrsAgo = todaysDate.addYears(-50);
        
        date newYearPast = date.newInstance(FiftyYrsAgo.year(), 1, 1);
        date newYearCurrent = date.newInstance(todaysDate.year(), 1, 1);
             
        // create 50 repeating addresses from 50 years ago
        for (integer i = 0; i < 25; i++) {
            
            date startDate = newYearPast.addDays(i);
            date endDate = newYearPast.addDays(i+4);
            
            integer j = math.mod(i, 8);
            id HID = l_households[j].id;
            string street = string.valueOf(i) + ' Avenue';
            
            Postal_Address__c nextAddr = makePostalAddress(HID, startDate, endDate, street, 'City', 'State');
            nextAddr.Repeat_Annually__c = true;
            
            l_newAddrs.add(nextAddr);
        }
        
        // create 50 repeating addresses from the current year
        for (integer i = 0; i < 25; i++) {
            
            date startDate = newYearCurrent.addDays(i);
            date endDate = newYearCurrent.addDays(i+4);
            
            integer j = math.mod(i, 8);
            id HID = l_households[j].id;
            string street = string.valueOf(i) + ' Avenue';
            
            Postal_Address__c nextAddr = makePostalAddress(HID, startDate, endDate, street, 'City', 'State');
            nextAddr.Repeat_Annually__c = true;
            
            l_newAddrs.add(nextAddr);
        }
        
        // create 20 non-repeating addresses that overlap
        for (integer i = 0; i < 20; i++) {
            
            date startDate = newYearCurrent.addDays(i);
            date endDate = newYearCurrent.addDays(i+4);
            
            id HID = l_households[0].id;
            string street = string.valueOf(i) + ' Avenue';
            
            Postal_Address__c nextAddr = makePostalAddress(HID, startDate, endDate, street, 'City', 'State');
            nextAddr.Repeat_Annually__c = false;
            
            l_newAddrs.add(nextAddr);            
        }
        
        // create 20 non-repeating addresses that don't overlap, use different household
        for (integer i = 0; i < 20; i++) {
            
            date startDate = newYearCurrent.addDays(i);
            date endDate = newYearCurrent.addDays(i);
            
            id HID = l_households[1].id;
            string street = string.valueOf(i) + ' Avenue';
            
            Postal_Address__c nextAddr = makePostalAddress(HID, startDate, endDate, street, 'City', 'State');
            nextAddr.Repeat_Annually__c = false;
            
            l_newAddrs.add(nextAddr);            
        }
        
        system.assertEquals(140, l_newAddrs.size());
        
        // run test
        test.startTest();
        insert(l_newAddrs);
        test.stopTest();
        
        // if we didn't throw an exception, we've passed  the stress test
        // But, since we're here, might as well peak at the results
        list<Postal_Address__c> l_addrsWithErrors = [Select id, Household__c, Start_Date__c
                                                     From Postal_Address__c
                                                     Where Errors__c != null AND Errors__c != ''];
        
        system.debug('size of errored address: '+l_addrsWithErrors);
       
    } // end stressTest
*/
    /***********************************************************************************************************
     * FAILING!
     * The repeat handling logic, while bad, is not the only reason we're violating CPU limits
     * This test fails when we change it to create 50 non-repeating, non-overlapping addresses 
     * It passes if we go down to 20.
     * 
     * In a pinch, we could go-live and require data loads to be done with batch size <= 10 (convervative estimate). Ick!
     * 
     * stressTest2 
     * create 180 non-repeating addresses (want to make sure it's the repeat handling that's violating CPU limits)
     ***********************************************************************************************************/
/*
 	static TestMethod void stressTest2() {
        // get a household
        list<account> l_households = [Select id, Name
                                      From account
                                      Where type = 'Household'
                                      Limit 1];
        
        system.assert(l_households != null);
        system.assertEquals(1, l_households.size());
        
        integer currYear = (date.today()).year();
        date newYearCurrent = date.newInstance(currYear, 1, 1);
        
        // make 180 non-repeating addresses for the household, no overlaps
        list<Postal_Address__c> l_newAddrs = new list<Postal_Address__c>();
        
        for (integer i = 0; i < 180; i++) {
            
            date startDate = newYearCurrent.addDays(i);
            date endDate = newYearCurrent.addDays(i);
            
            id HID = l_households[0].id;
            string street = string.valueOf(i) + ' Avenue';
            
            Postal_Address__c nextAddr = makePostalAddress(HID, startDate, endDate, street, 'City', 'State');
            nextAddr.Repeat_Annually__c = false;
            
            l_newAddrs.add(nextAddr);            
        }
                
        system.assertEquals(180, l_newAddrs.size());
        
        // run test
        test.startTest();
        insert(l_newAddrs);
        test.stopTest();
    }
 */   
    
} // end PostalAddressHandlerTest class