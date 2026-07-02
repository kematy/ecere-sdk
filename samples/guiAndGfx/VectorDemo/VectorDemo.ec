import "ecere"
import "Vector"
import "VectorRenderer"

// Vector / CAD demo: load ASCII DXF, select entities, drag grips to edit, export DXF.
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
   SelectionManager selection { };
   SemanticEntity selectedEntity;
   InteractionOverlay overlay;
   char statusText[512];
   bool draggingGrip;
   int dragGripIndex;

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
      VectorPoint hatchBoundary[4] =
      {
         { 280, 120, 0 }, { 360, 120, 0 }, { 360, 180, 0 }, { 280, 180, 0 }
      };

      document.CreateLine({ 0, 0, 0 }, { 100, 0, 0 }, "GRID");
      document.CreateCircle({ 160, 60, 0 }, 35, "OBJECTS");
      document.CreateArc({ 220, 60, 0 }, 30, 0, 180, "OBJECTS");
      document.CreateEllipse({ 300, 60, 0 }, 45, 20, 0, "OBJECTS");
      document.CreatePolyline(poly, 4, true, "OBJECTS");
      document.CreateSpline(splinePoints, 4, 3, false, "OBJECTS");
      document.CreateText({ 20, 220, 0 }, { 20, 220, 0 }, "Hello", 12, "STANDARD", "ANNOTATION");
      document.CreateHatch({ 320, 150, 0 }, hatchBoundary, 4, "SOLID", "OBJECTS");
      document.RebuildSemanticDisplayLines();
   }

   bool ExportDocument(const char * exportPath)
   {
      DXFWriter writer { };
      if(writer.Save(document, exportPath))
      {
         sprintf(statusText, "Exported DXF: %s (%d entities)", exportPath, document.entities.count);
         return true;
      }
      sprintf(statusText, "DXF export failed: %s", writer.GetLastError());
      return false;
   }

   void EnsureRendererFit()
   {
      VectorBounds b;
      if(document.displayLines.count)
      {
         b = renderer.DocumentBounds(document);
         renderer.Fit(b, clientSize.w, clientSize.h, 40);
      }
   }

   double PickTolerance()
   {
      return 8.0 / (renderer.scale > 0 ? renderer.scale : 1);
   }

   void RefreshOverlay()
   {
      delete overlay;
      overlay = selectedEntity ? selection.BuildOverlay(selectedEntity) : null;
   }

   VectorDemo()
   {
      GuiApplication app = (GuiApplication)__thisModule;
      const char * inputPath = null;
      const char * exportPath = null;
      int c;

      statusText[0] = 0;
      draggingGrip = false;
      dragGripIndex = -1;

      for(c = 1; c < app.argc; c++)
      {
         if(!strcmp(app.argv[c], "--export") && c + 1 < app.argc)
         {
            exportPath = app.argv[c + 1];
            c++;
         }
         else if(!inputPath)
            inputPath = app.argv[c];
      }

      if(inputPath)
      {
         DXFReader reader { };
         if(reader.Load(document, inputPath))
            sprintf(statusText, "Loaded DXF: %s (%d entities, %d display lines)", inputPath, document.entities.count, document.displayLines.count);
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
            sprintf(statusText, "Loaded %s (%d entities, %d display lines)", samplePath, document.entities.count, document.displayLines.count);
         else
         {
            BuildBuiltinDemo();
            sprintf(statusText, "Built-in demo: %d entities, %d display lines", document.entities.count, document.displayLines.count);
         }
      }

      if(exportPath)
      {
         char exportStatus[256];
         if(ExportDocument(exportPath))
            sprintf(exportStatus, " | Exported to %s", exportPath);
         else
            sprintf(exportStatus, " | Export failed");
         strncat(statusText, exportStatus, sizeof(statusText) - strlen(statusText) - 1);
      }
   }

   ~VectorDemo()
   {
      delete overlay;
   }

   const char * EntityTypeName(SemanticEntityType type)
   {
      switch(type)
      {
         case entityLine: return "LINE";
         case entityCircle: return "CIRCLE";
         case entityArc: return "ARC";
         case entityEllipse: return "ELLIPSE";
         case entityPolyline: return "POLYLINE";
         case entitySpline: return "SPLINE";
         case entityText: return "TEXT";
         case entityInsert: return "INSERT";
         case entityLeader: return "LEADER";
         case entityHatch: return "HATCH";
      }
      return "ENTITY";
   }

   bool OnLeftButtonDown(int x, int y, Modifiers mods)
   {
      VectorPoint world;
      double tolerance;
      int gripIndex;

      EnsureRendererFit();
      world = renderer.ScreenToWorld({ x, y });
      tolerance = PickTolerance();

      if(selectedEntity && overlay)
      {
         gripIndex = selection.PickGrip(overlay, world, tolerance);
         if(gripIndex >= 0)
         {
            draggingGrip = true;
            dragGripIndex = gripIndex;
            sprintf(statusText, "Dragging grip %d on %s #" FORMAT64U, gripIndex, EntityTypeName(selectedEntity.type), selectedEntity.id);
            return true;
         }
      }

      draggingGrip = false;
      dragGripIndex = -1;
      delete overlay;
      overlay = null;
      selectedEntity = selection.PickEntity(document, world, tolerance);

      if(selectedEntity)
      {
         overlay = selection.BuildOverlay(selectedEntity);
         sprintf(statusText, "Selected %s #" FORMAT64U " (%d grips)", EntityTypeName(selectedEntity.type), selectedEntity.id, overlay ? overlay.pointCount : 0);
      }
      else
         sprintf(statusText, "No entity at click (world %.4f, %.4f)", world.x, world.y);

      Update(null);
      return true;
   }

   bool OnLeftButtonUp(int x, int y, Modifiers mods)
   {
      if(draggingGrip)
      {
         draggingGrip = false;
         dragGripIndex = -1;
         if(selectedEntity)
            sprintf(statusText, "Updated %s #" FORMAT64U, EntityTypeName(selectedEntity.type), selectedEntity.id);
      }
      return true;
   }

   bool OnMouseMove(int x, int y, Modifiers mods)
   {
      VectorPoint world;

      if(!draggingGrip || !selectedEntity || dragGripIndex < 0)
         return true;

      EnsureRendererFit();
      world = renderer.ScreenToWorld({ x, y });

      if(selection.ApplyGripMove(selectedEntity, dragGripIndex, world))
      {
         document.RebuildSemanticDisplayLines();
         RefreshOverlay();
         Update(null);
      }

      return true;
   }

   void OnRedraw(Surface surface)
   {
      renderer.DrawDocument(surface, document, clientSize.w, clientSize.h);

      if(selectedEntity)
      {
         renderer.DrawSelectedEntity(surface, document, selectedEntity.id);
         if(overlay)
            renderer.DrawInteractionOverlay(surface, overlay);
      }

      surface.SetForeground(black);
      surface.WriteTextf(12, 10, "%s", statusText);
      surface.SetForeground(Color { 30, 30, 30 });
      surface.WriteTextf(12, 28, "industrial (dark)");
      surface.SetForeground(Color { 30, 90, 210 });
      surface.WriteTextf(140, 28, "artistic (blue)");
      surface.SetForeground(Color { 100, 100, 100 });
      surface.WriteTextf(12, clientSize.h - 20, "Click to select; drag red grips to edit");
   }
}

VectorDemo mainForm { };
