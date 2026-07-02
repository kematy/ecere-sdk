import "ecere"
import "Vector"
import "VectorRenderer"

// Phase 0 + 1 demo: builds a small CAD document (line, circle, arc, ellipse,
// closed polyline, spline, text), resolves it to DisplayLines through the shared
// RebuildSemanticDisplayLines() path, and renders those lines with VectorRenderer.
class VectorDemo : Window
{
   text = "Ecere eC - Vector / CAD DisplayLine Demo (Phase 0+1)";
   background = white;
   borderStyle = sizable;
   hasMaximize = true;
   hasMinimize = true;
   hasClose = true;
   size = { 900, 640 };

   CADDocument document { };
   VectorRenderer renderer { };

   VectorDemo()
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
   }

   void OnRedraw(Surface surface)
   {
      renderer.DrawDocument(surface, document, clientSize.w, clientSize.h);

      surface.SetForeground(black);
      surface.WriteTextf(12, 10, "Entities: %d   DisplayLines: %d", document.entities.count, document.displayLines.count);
      surface.SetForeground(Color { 30, 30, 30 });
      surface.WriteTextf(12, 28, "industrial (dark)");
      surface.SetForeground(Color { 30, 90, 210 });
      surface.WriteTextf(140, 28, "artistic (blue)");
   }
}

VectorDemo mainForm { };
