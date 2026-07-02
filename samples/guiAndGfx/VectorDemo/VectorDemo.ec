import "ecere"
import "Vector"
import "VectorRenderer"

// Vector / CAD demo: built-in shapes or load an ASCII DXF file from the command line.
//   VectorDemo
//   VectorDemo path/to/file.dxf
class VectorDemo : Window
{
   text = "Ecere eC - Vector / CAD / DXF Demo";
   background = white;
   borderStyle = sizable;
   hasMaximize = true;
   hasMinimize = true;
   hasClose = true;
   size = { 900, 640 };

   CADDocument document { };
   VectorRenderer renderer { };
   char statusText[512];

   void BuildBuiltinDemo()
   {
      VectorPoint poly[4] =
      {
         { 0, 60, 0 }, { 120, 60, 0 }, { 120, 120, 0 }, { 0, 120, 0 }
      };
      VectorPoint splinePoints[4] =
      {
         { 0, 150, 0 }, { 40, 190, 0 }, { 80, 150, 0 }, { 120, 190, 0 }
      };

      document.CreateLine({ 0, 0, 0 }, { 100, 0, 0 }, "GRID");
      document.CreateCircle({ 160, 60, 0 }, 35, "OBJECTS");
      document.CreateArc({ 220, 60, 0 }, 30, 0, 180, "OBJECTS");
      document.CreateEllipse({ 300, 60, 0 }, 45, 20, 0, "OBJECTS");
      document.CreatePolyline(poly, 4, true, "OBJECTS");
      document.CreateSpline(splinePoints, 4, 3, false, "OBJECTS");
      document.CreateText({ 20, 220, 0 }, { 20, 220, 0 }, "Hello", 12, "STANDARD", "ANNOTATION");
      document.RebuildSemanticDisplayLines();
      sprintf(statusText, "Built-in demo: %d entities, %d display lines", document.entities.count, document.displayLines.count);
   }

   VectorDemo()
   {
      statusText[0] = 0;

      if(((GuiApplication)__thisModule).argc > 1)
      {
         const char * path = ((GuiApplication)__thisModule).argv[1];
         DXFReader reader { };
         if(reader.Load(document, path))
            sprintf(statusText, "Loaded DXF: %s (%d entities, %d display lines)", path, document.entities.count, document.displayLines.count);
         else
         {
            BuildBuiltinDemo();
            sprintf(statusText, "DXF load failed (%s). Showing built-in demo.", reader.GetLastError());
         }
      }
      else
      {
         const char * samplePath = "sample.dxf";
         DXFReader reader { };
         if(reader.Load(document, samplePath))
            sprintf(statusText, "Loaded %s (%d entities, %d display lines). Pass a .dxf path on the command line to open another file.", samplePath, document.entities.count, document.displayLines.count);
         else
            BuildBuiltinDemo();
      }
   }

   void OnRedraw(Surface surface)
   {
      renderer.DrawDocument(surface, document, clientSize.w, clientSize.h);

      surface.SetForeground(black);
      surface.WriteTextf(12, 10, "%s", statusText);
      surface.SetForeground(Color { 30, 30, 30 });
      surface.WriteTextf(12, 28, "industrial (dark)");
      surface.SetForeground(Color { 30, 90, 210 });
      surface.WriteTextf(140, 28, "artistic (blue)");
   }
}

VectorDemo mainForm { };
