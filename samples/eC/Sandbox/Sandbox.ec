import "ecere"

class SandboxApp : Application
{
   void Main()
   {
      int c;

      PrintLn("Ecere SDK sandbox");
      PrintLn("-----------------");
      PrintLn("Edit samples/eC/Sandbox/Sandbox.ec to try eC language and Ecere APIs.");
      PrintLn("");
      PrintLn("Command line arguments:");

      if(argc <= 1)
         PrintLn("  (none)");
      else
      {
         for(c = 1; c < argc; c++)
            PrintLn("  ", c, ": ", argv[c]);
      }
   }
}
