/********************************************************************************
 * Name             : CheckForRecursion
 * Created By       : Vicky Weissman
 * Created Date     : August 2016
 * Purpose          : Use to prevent recursion 
 * Notes            : Can be used for all triggers
********************************************************************************/

public class CheckForRecursion {
    private static Boolean b_FirstRun = true;
    
    // return true on first call in execution context; false on subsequent calls
    public static Boolean firstRun () {
        if(b_FirstRun) {
            b_FirstRun = false;
            return true;
        } else {
            return false;
        }
    } // end firstRun method

} // end CheckForRecursion