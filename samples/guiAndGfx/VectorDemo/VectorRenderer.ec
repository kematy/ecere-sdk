import "ecere"
public import "Vector"

// Phase 1 rendering closure: turns a CADDocument's resolved DisplayLines into
// actual strokes on an Ecere Surface. Ellipse arcs and (fallback) spline lines
// are tessellated into short segments; a world->screen transform fits and
// centers the drawing (flipping Y so CAD "up" maps to screen "up").
class VectorRenderer
{
public:
   double scale;
   double originX, originY;
   double left, bottom;
   bool ready;

   void Fit(VectorBounds world, int screenW, int screenH, int margin)
   {
      double worldW = world.right - world.left;
      double worldH = world.bottom - world.top;
      double sx, sy, drawnW, drawnH;

      if(worldW <= 0) worldW = 1;
      if(worldH <= 0) worldH = 1;

      sx = (double)(screenW - 2 * margin) / worldW;
      sy = (double)(screenH - 2 * margin) / worldH;
      scale = sx < sy ? sx : sy;
      if(scale <= 0) scale = 1;

      drawnW = worldW * scale;
      drawnH = worldH * scale;
      originX = margin + ((screenW - 2 * margin) - drawnW) / 2;
      originY = margin + ((screenH - 2 * margin) - drawnH) / 2;
      left = world.left;
      bottom = world.bottom;
      ready = true;
   }

   Point ToScreen(VectorPoint p)
   {
      double sx = originX + (p.x - left) * scale;
      double sy = originY + (bottom - p.y) * scale;
      return
      {
         (int)(sx >= 0 ? sx + 0.5 : sx - 0.5),
         (int)(sy >= 0 ? sy + 0.5 : sy - 0.5)
      };
   }

   VectorPoint ScreenToWorld(Point sp)
   {
      return
      {
         left + (sp.x - originX) / scale,
         bottom - (sp.y - originY) / scale,
         0
      };
   }

   VectorBounds DocumentBounds(CADDocument doc)
   {
      VectorBounds all;
      Link link;
      all.Reset();
      for(link = doc.displayLines.first; link; link = link.next)
      {
         DisplayLine dl = (DisplayLine)doc.displayLines.GetData(link);
         if(dl)
         {
            all.IncludePoint({ dl.bounds.left, dl.bounds.top, 0 });
            all.IncludePoint({ dl.bounds.right, dl.bounds.bottom, 0 });
         }
      }
      return all;
   }

   void DrawDisplayLine(Surface surface, DisplayLine dl)
   {
      bool hasPrev = false;
      Point prev, first;

      if(!dl) return;

      if(dl.implementation == ellipseArc)
      {
         double a0 = dl.startAngle, a1 = dl.endAngle;
         double rot = VectorDegreesToRadians(dl.rotation);
         double cr = cos(rot), sr = sin(rot);
         double sweep;
         uint steps, i;

         if(a1 < a0) a1 += 360;
         sweep = a1 - a0;
         steps = VectorArcSampleCount(sweep, dl.radiusX > dl.radiusY ? dl.radiusX : dl.radiusY, 32, 512);

         for(i = 0; i <= steps; i++)
         {
            double ang = VectorDegreesToRadians(a0 + sweep * (double)i / (double)steps);
            double ex = dl.radiusX * cos(ang);
            double ey = dl.radiusY * sin(ang);
            VectorPoint wp =
            {
               dl.center.x + ex * cr - ey * sr,
               dl.center.y + ex * sr + ey * cr,
               dl.center.z
            };
            Point sp = ToScreen(wp);
            if(hasPrev)
               surface.DrawLine(prev.x, prev.y, sp.x, sp.y);
            else
               first = sp;
            prev = sp;
            hasPrev = true;
         }
      }
      else
      {
         uint c;
         for(c = 0; c < dl.pointCount; c++)
         {
            Point sp = ToScreen(dl.points[c]);
            if(hasPrev)
               surface.DrawLine(prev.x, prev.y, sp.x, sp.y);
            else
               first = sp;
            prev = sp;
            hasPrev = true;
         }
      }

      if(dl.closed && hasPrev)
         surface.DrawLine(prev.x, prev.y, first.x, first.y);
   }

   void DrawDocument(Surface surface, CADDocument doc, int screenW, int screenH)
   {
      Link link;
      VectorBounds b;

      if(!doc || !doc.displayLines.count) return;

      b = DocumentBounds(doc);
      Fit(b, screenW, screenH, 40);

      for(link = doc.displayLines.first; link; link = link.next)
      {
         DisplayLine dl = (DisplayLine)doc.displayLines.GetData(link);
         if(!dl) continue;
         // Industrial lines drawn dark, artistic lines drawn in a distinct accent color
         surface.SetForeground(dl.kind == industrial ? Color { 30, 30, 30 } : Color { 30, 90, 210 });
         DrawDisplayLine(surface, dl);
      }
   }

   void DrawSelectedEntity(Surface surface, CADDocument doc, uint64 entityId)
   {
      Link link;

      if(!doc || !entityId) return;

      surface.SetForeground(Color { 230, 90, 20 });
      for(link = doc.displayLines.first; link; link = link.next)
      {
         DisplayLine dl = (DisplayLine)doc.displayLines.GetData(link);
         if(dl && dl.ownerEntityId == entityId)
            DrawDisplayLine(surface, dl);
      }
   }

   void DrawInteractionOverlay(Surface surface, InteractionOverlay overlay)
   {
      uint c;
      int gripSize = 4;

      if(!overlay || !overlay.points) return;

      for(c = 0; c < overlay.pointCount; c++)
      {
         Point sp = ToScreen(overlay.points[c].point);

         if(overlay.points[c].kind == snap)
         {
            int snapSize = 5;
            surface.SetForeground(Color { 20, 180, 80 });
            surface.DrawLine(sp.x, sp.y - snapSize, sp.x + snapSize, sp.y);
            surface.DrawLine(sp.x + snapSize, sp.y, sp.x, sp.y + snapSize);
            surface.DrawLine(sp.x, sp.y + snapSize, sp.x - snapSize, sp.y);
            surface.DrawLine(sp.x - snapSize, sp.y, sp.x, sp.y - snapSize);
         }
         else if(overlay.points[c].kind == constraint)
         {
            int mark = 5;
            surface.SetForeground(Color { 30, 120, 220 });
            surface.DrawLine(sp.x - mark, sp.y, sp.x + mark, sp.y);
            surface.DrawLine(sp.x, sp.y - mark, sp.x, sp.y + mark);
         }
         else
         {
            surface.SetForeground(Color { 220, 40, 40 });
            surface.DrawLine(sp.x - gripSize, sp.y - gripSize, sp.x + gripSize, sp.y - gripSize);
            surface.DrawLine(sp.x + gripSize, sp.y - gripSize, sp.x + gripSize, sp.y + gripSize);
            surface.DrawLine(sp.x + gripSize, sp.y + gripSize, sp.x - gripSize, sp.y + gripSize);
            surface.DrawLine(sp.x - gripSize, sp.y + gripSize, sp.x - gripSize, sp.y - gripSize);
         }
      }
   }

   void DrawSnapPoint(Surface surface, VectorPoint worldPoint)
   {
      int snapSize = 5;
      Point sp = ToScreen(worldPoint);

      surface.SetForeground(Color { 20, 180, 80 });
      surface.DrawLine(sp.x, sp.y - snapSize, sp.x + snapSize, sp.y);
      surface.DrawLine(sp.x + snapSize, sp.y, sp.x, sp.y + snapSize);
      surface.DrawLine(sp.x, sp.y + snapSize, sp.x - snapSize, sp.y);
      surface.DrawLine(sp.x - snapSize, sp.y, sp.x, sp.y - snapSize);
   }
};
