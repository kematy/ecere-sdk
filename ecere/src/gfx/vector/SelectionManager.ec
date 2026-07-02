namespace gfx::vector;

import "Geometry"
import "CADDocument"
import "InteractionOverlay"

// Phase 4: entity picking and grip overlay construction.
public class SelectionManager
{
   double PointDistance(VectorPoint a, VectorPoint b)
   {
      double dx = a.x - b.x;
      double dy = a.y - b.y;
      return sqrt(dx * dx + dy * dy);
   }

   double PointSegmentDistance(VectorPoint p, VectorPoint a, VectorPoint b)
   {
      double dx = b.x - a.x;
      double dy = b.y - a.y;
      double len2 = dx * dx + dy * dy;
      double t;

      if(VectorIsZero(len2, VECTOR_GEOM_EPSILON))
         return PointDistance(p, a);

      t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2;
      if(t < 0) t = 0;
      else if(t > 1) t = 1;

      return PointDistance(p, { a.x + t * dx, a.y + t * dy, a.z + t * (b.z - a.z) });
   }

   VectorPoint ArcPoint(DisplayLine dl, double angleDegrees)
   {
      double ang = VectorDegreesToRadians(angleDegrees);
      double ex = dl.radiusX * cos(ang);
      double ey = dl.radiusY * sin(ang);
      double rot = VectorDegreesToRadians(dl.rotation);
      double cr = cos(rot), sr = sin(rot);

      return
      {
         dl.center.x + ex * cr - ey * sr,
         dl.center.y + ex * sr + ey * cr,
         dl.center.z
      };
   }

   double DisplayLineDistance(DisplayLine dl, VectorPoint p)
   {
      double best = 1.0e300;

      if(!dl)
         return best;

      if(dl.implementation == ellipseArc)
      {
         double a0 = dl.startAngle, a1 = dl.endAngle;
         double sweep;
         uint steps, i;
         VectorPoint prev;
         bool hasPrev = false;

         if(a1 < a0) a1 += 360;
         sweep = a1 - a0;
         steps = VectorArcSampleCount(sweep, dl.radiusX > dl.radiusY ? dl.radiusX : dl.radiusY, 32, 512);

         for(i = 0; i <= steps; i++)
         {
            VectorPoint wp = ArcPoint(dl, a0 + sweep * (double)i / (double)steps);
            if(hasPrev)
            {
               double d = PointSegmentDistance(p, prev, wp);
               if(d < best)
                  best = d;
            }
            prev = wp;
            hasPrev = true;
         }
      }
      else if(dl.pointCount)
      {
         uint c;
         for(c = 0; c + 1 < dl.pointCount; c++)
         {
            double d = PointSegmentDistance(p, dl.points[c], dl.points[c + 1]);
            if(d < best)
               best = d;
         }
         if(dl.closed && dl.pointCount > 1)
         {
            double d = PointSegmentDistance(p, dl.points[dl.pointCount - 1], dl.points[0]);
            if(d < best)
               best = d;
         }
      }

      return best;
   }

   SemanticEntity FindEntity(CADDocument doc, uint64 id)
   {
      Link link;

      if(doc && id)
      {
         for(link = doc.entities.first; link; link = link.next)
         {
            SemanticEntity entity = (SemanticEntity)doc.entities.GetData(link);
            if(entity && entity.id == id)
               return entity;
         }
      }
      return null;
   }

   void IncludePoint(VectorBounds & bounds, VectorPoint p)
   {
      bounds.IncludePoint(p);
   }

   VectorPoint ArcEndpoint(VectorPoint center, double radius, double angleDegrees)
   {
      double ang = VectorDegreesToRadians(angleDegrees);
      return { center.x + radius * cos(ang), center.y + radius * sin(ang), center.z };
   }

   uint CountGripPoints(SemanticEntity entity)
   {
      if(!entity)
         return 0;

      switch(entity.type)
      {
         case entityLine: return 2;
         case entityCircle: return 2;
         case entityArc: return 3;
         case entityEllipse: return 2;
         case entityPolyline:
         {
            PolylineEntity poly = (PolylineEntity)entity;
            return poly.pointCount;
         }
         case entitySpline:
         {
            SplineEntity spline = (SplineEntity)entity;
            return spline.controlPointCount;
         }
         case entityText: return 1;
         case entityInsert: return 1;
         case entityLeader:
         {
            LeaderEntity leader = (LeaderEntity)entity;
            return leader.pointCount;
         }
         case entityHatch:
         {
            HatchEntity hatch = (HatchEntity)entity;
            return hatch.boundaryPointCount ? hatch.boundaryPointCount : 1;
         }
      }
      return 0;
   }

   void AddGrip(InteractionPoint * points, uint & index, VectorPoint p)
   {
      points[index].kind = grip;
      points[index].point = p;
      index++;
   }

   void FillGripPoints(SemanticEntity entity, InteractionPoint * points, VectorBounds & bounds)
   {
      uint index = 0;

      if(!entity || !points)
         return;

      bounds.Reset();

      switch(entity.type)
      {
         case entityLine:
         {
            LineEntity line = (LineEntity)entity;
            AddGrip(points, index, line.start);
            AddGrip(points, index, line.end);
            break;
         }
         case entityCircle:
         {
            CircleEntity circle = (CircleEntity)entity;
            AddGrip(points, index, circle.center);
            AddGrip(points, index, { circle.center.x + circle.radius, circle.center.y, circle.center.z });
            break;
         }
         case entityArc:
         {
            ArcEntity arc = (ArcEntity)entity;
            AddGrip(points, index, arc.center);
            AddGrip(points, index, ArcEndpoint(arc.center, arc.radius, arc.startAngle));
            AddGrip(points, index, ArcEndpoint(arc.center, arc.radius, arc.endAngle));
            break;
         }
         case entityEllipse:
         {
            EllipseEntity ellipse = (EllipseEntity)entity;
            AddGrip(points, index, ellipse.center);
            AddGrip(points, index, { ellipse.center.x + ellipse.radiusX, ellipse.center.y, ellipse.center.z });
            break;
         }
         case entityPolyline:
         {
            PolylineEntity poly = (PolylineEntity)entity;
            uint c;
            for(c = 0; c < poly.pointCount; c++)
               AddGrip(points, index, poly.points[c]);
            break;
         }
         case entitySpline:
         {
            SplineEntity spline = (SplineEntity)entity;
            uint c;
            for(c = 0; c < spline.controlPointCount; c++)
               AddGrip(points, index, spline.controlPoints[c]);
            break;
         }
         case entityText:
         {
            TextEntity text = (TextEntity)entity;
            AddGrip(points, index, text.position);
            break;
         }
         case entityInsert:
         {
            InsertEntity insert = (InsertEntity)entity;
            AddGrip(points, index, insert.position);
            break;
         }
         case entityLeader:
         {
            LeaderEntity leader = (LeaderEntity)entity;
            uint c;
            for(c = 0; c < leader.pointCount; c++)
               AddGrip(points, index, leader.points[c]);
            break;
         }
         case entityHatch:
         {
            HatchEntity hatch = (HatchEntity)entity;
            if(hatch.boundaryPointCount)
            {
               uint c;
               for(c = 0; c < hatch.boundaryPointCount; c++)
                  AddGrip(points, index, hatch.boundaryPoints[c]);
            }
            else
               AddGrip(points, index, hatch.seed);
            break;
         }
      }

      {
         uint c;
         for(c = 0; c < index; c++)
            IncludePoint(bounds, points[c].point);
      }
   }

   public SemanticEntity PickEntity(CADDocument doc, VectorPoint world, double tolerance)
   {
      Link link;
      double bestDistance = tolerance;
      uint64 bestEntityId = 0;

      if(!doc)
         return null;

      for(link = doc.displayLines.first; link; link = link.next)
      {
         DisplayLine dl = (DisplayLine)doc.displayLines.GetData(link);
         double distance;

         if(!dl)
            continue;

         distance = DisplayLineDistance(dl, world);
         if(distance <= bestDistance)
         {
            bestDistance = distance;
            bestEntityId = dl.ownerEntityId;
         }
      }

      return bestEntityId ? FindEntity(doc, bestEntityId) : null;
   }

   public InteractionOverlay BuildOverlay(SemanticEntity entity)
   {
      uint count = CountGripPoints(entity);
      InteractionOverlay overlay { ownerEntityId = entity ? entity.id : 0 };

      overlay.pointCount = count;
      overlay.points = count ? new InteractionPoint[count] : null;
      if(entity && overlay.points)
         FillGripPoints(entity, overlay.points, overlay.selectionBounds);

      return overlay;
   }

   public int PickGrip(InteractionOverlay overlay, VectorPoint world, double tolerance)
   {
      uint c;
      int best = -1;
      double bestDistance = tolerance;

      if(!overlay || !overlay.points)
         return -1;

      for(c = 0; c < overlay.pointCount; c++)
      {
         double distance = PointDistance(world, overlay.points[c].point);
         if(distance <= bestDistance)
         {
            bestDistance = distance;
            best = (int)c;
         }
      }

      return best;
   }

   public bool ApplyGripMove(SemanticEntity entity, int gripIndex, VectorPoint newPoint)
   {
      if(!entity || gripIndex < 0)
         return false;

      switch(entity.type)
      {
         case entityLine:
         {
            LineEntity line = (LineEntity)entity;
            if(gripIndex == 0)
               line.start = newPoint;
            else if(gripIndex == 1)
               line.end = newPoint;
            else
               return false;
            line.Touch();
            break;
         }
         case entityCircle:
         {
            CircleEntity circle = (CircleEntity)entity;
            if(gripIndex == 0)
               circle.center = newPoint;
            else if(gripIndex == 1)
            {
               double dx = newPoint.x - circle.center.x;
               double dy = newPoint.y - circle.center.y;
               circle.radius = sqrt(dx * dx + dy * dy);
            }
            else
               return false;
            circle.Touch();
            break;
         }
         case entityArc:
         {
            ArcEntity arc = (ArcEntity)entity;
            if(gripIndex == 0)
               arc.center = newPoint;
            else if(gripIndex == 1)
               arc.startAngle = VectorRadiansToDegrees(atan2(newPoint.y - arc.center.y, newPoint.x - arc.center.x));
            else if(gripIndex == 2)
               arc.endAngle = VectorRadiansToDegrees(atan2(newPoint.y - arc.center.y, newPoint.x - arc.center.x));
            else
               return false;
            arc.Touch();
            break;
         }
         case entityEllipse:
         {
            EllipseEntity ellipse = (EllipseEntity)entity;
            if(gripIndex == 0)
               ellipse.center = newPoint;
            else if(gripIndex == 1)
            {
               double dx = newPoint.x - ellipse.center.x;
               double dy = newPoint.y - ellipse.center.y;
               ellipse.radiusX = sqrt(dx * dx + dy * dy);
            }
            else
               return false;
            ellipse.Touch();
            break;
         }
         case entityPolyline:
         {
            PolylineEntity poly = (PolylineEntity)entity;
            if((uint)gripIndex >= poly.pointCount || !poly.points)
               return false;
            poly.points[gripIndex] = newPoint;
            poly.Touch();
            break;
         }
         case entitySpline:
         {
            SplineEntity spline = (SplineEntity)entity;
            if((uint)gripIndex >= spline.controlPointCount || !spline.controlPoints)
               return false;
            spline.controlPoints[gripIndex] = newPoint;
            spline.Touch();
            break;
         }
         case entityText:
         {
            TextEntity text = (TextEntity)entity;
            if(gripIndex != 0)
               return false;
            text.position = newPoint;
            text.alignment = newPoint;
            text.Touch();
            break;
         }
         case entityInsert:
         {
            InsertEntity insert = (InsertEntity)entity;
            if(gripIndex != 0)
               return false;
            insert.position = newPoint;
            insert.Touch();
            break;
         }
         case entityLeader:
         {
            LeaderEntity leader = (LeaderEntity)entity;
            if((uint)gripIndex >= leader.pointCount || !leader.points)
               return false;
            leader.points[gripIndex] = newPoint;
            leader.Touch();
            break;
         }
         case entityHatch:
         {
            HatchEntity hatch = (HatchEntity)entity;
            if(hatch.boundaryPointCount && hatch.boundaryPoints)
            {
               if((uint)gripIndex >= hatch.boundaryPointCount)
                  return false;
               hatch.boundaryPoints[gripIndex] = newPoint;
            }
            else if(gripIndex == 0)
               hatch.seed = newPoint;
            else
               return false;
            hatch.Touch();
            break;
         }
         default:
            return false;
      }

      return true;
   }
};
