import "ecere"
import "Vector"

// Headless DXF load + export for CI round-trip validation (no GUI).
class DXFRoundTripApp : Application
{
   void Main()
   {
      const char * inputPath;
      const char * outputPath;
      CADDocument document { };
      DXFReader reader { };
      DXFWriter writer { };

      if(argc < 3)
      {
         PrintLn("Usage: DXFRoundTrip <input.dxf> <output.dxf>");
         exitCode = 2;
         return;
      }

      inputPath = argv[1];
      outputPath = argv[2];

      if(!reader.Load(document, inputPath))
      {
         PrintLn("DXF load failed: ", reader.GetLastError());
         exitCode = 1;
         return;
      }

      if(!writer.Save(document, outputPath))
      {
         PrintLn("DXF export failed: ", writer.GetLastError());
         exitCode = 1;
         return;
      }

      PrintLn("OK: exported ", document.entities.count, " entities to ", outputPath);
      exitCode = 0;
   }
}
