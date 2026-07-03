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

   void IncludePoint(VectorBounds * bounds, VectorPoint p)
   {
      if(bounds)
         (*bounds).IncludePoint(p);
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
         case entityDimension: return 4;
      }
      return 0;
   }

   void AddGrip(InteractionPoint * points, uint * index, VectorPoint p)
   {
      if(!points || !index)
         return;
      points[*index].kind = grip;
      points[*index].point = p;
      (*index)++;
   }

   VectorPoint MidPoint(VectorPoint a, VectorPoint b)
   {
      return { (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5 };
   }

   void ConsiderSnap(VectorPoint candidate, VectorPoint world, double * bestDistance, InteractionPoint * best, bool * found)
   {
      double distance;
      if(!bestDistance || !best || !found)
         return;
      distance = PointDistance(candidate, world);
      if(distance <= *bestDistance)
      {
         *bestDistance = distance;
         (*best).kind = snap;
         (*best).point = candidate;
         *found = true;
      }
   }

   void CollectEntitySnapPoints(SemanticEntity entity, VectorPoint world, double tolerance, InteractionPoint * best, double * bestDistance, bool * found)
   {
      if(!entity)
         return;

      switch(entity.type)
      {
         case entityLine:
         {
            LineEntity line = (LineEntity)entity;
            VectorPoint mid = MidPoint(line.start, line.end);
            ConsiderSnap(line.start, world, bestDistance, best, found);
            ConsiderSnap(line.end, world, bestDistance, best, found);
            ConsiderSnap(mid, world, bestDistance, best, found);
            break;
         }
         case entityCircle:
         {
            CircleEntity circle = (CircleEntity)entity;
            VectorPoint east = { circle.center.x + circle.radius, circle.center.y, circle.center.z };
            VectorPoint north = { circle.center.x, circle.center.y + circle.radius, circle.center.z };
            ConsiderSnap(circle.center, world, bestDistance, best, found);
            ConsiderSnap(east, world, bestDistance, best, found);
            ConsiderSnap(north, world, bestDistance, best, found);
            break;
         }
         case entityArc:
         {
            ArcEntity arc = (ArcEntity)entity;
            double midAngle = (arc.startAngle + arc.endAngle) * 0.5;
            VectorPoint startPt = ArcEndpoint(arc.center, arc.radius, arc.startAngle);
            VectorPoint endPt = ArcEndpoint(arc.center, arc.radius, arc.endAngle);
            VectorPoint midPt = ArcEndpoint(arc.center, arc.radius, midAngle);
            ConsiderSnap(arc.center, world, bestDistance, best, found);
            ConsiderSnap(startPt, world, bestDistance, best, found);
            ConsiderSnap(endPt, world, bestDistance, best, found);
            ConsiderSnap(midPt, world, bestDistance, best, found);
            break;
         }
         case entityEllipse:
         {
            EllipseEntity ellipse = (EllipseEntity)entity;
            ConsiderSnap(ellipse.center, world, bestDistance, best, found);
            break;
         }
         case entityPolyline:
         {
            PolylineEntity poly = (PolylineEntity)entity;
            uint c, segCount;
            if(poly.pointCount && poly.points)
            {
               for(c = 0; c < poly.pointCount; c++)
                  ConsiderSnap(poly.points[c], world, bestDistance, best, found);
               segCount = poly.closed ? poly.pointCount : (poly.pointCount > 1 ? poly.pointCount - 1 : 0);
               for(c = 0; c < segCount; c++)
               {
                  uint next = (c + 1) % poly.pointCount;
                  VectorPoint mid = MidPoint(poly.points[c], poly.points[next]);
                  ConsiderSnap(mid, world, bestDistance, best, found);
               }
            }
            break;
         }
         case entitySpline:
         {
            SplineEntity spline = (SplineEntity)entity;
            uint c;
            if(spline.controlPointCount && spline.controlPoints)
            {
               for(c = 0; c < spline.controlPointCount; c++)
                  ConsiderSnap(spline.controlPoints[c], world, bestDistance, best, found);
               for(c = 0; c + 1 < spline.controlPointCount; c++)
               {
                  VectorPoint mid = MidPoint(spline.controlPoints[c], spline.controlPoints[c + 1]);
                  ConsiderSnap(mid, world, bestDistance, best, found);
               }
            }
            break;
         }
         case entityText:
         {
            TextEntity text = (TextEntity)entity;
            ConsiderSnap(text.position, world, bestDistance, best, found);
            break;
         }
         case entityInsert:
         {
            InsertEntity insert = (InsertEntity)entity;
            ConsiderSnap(insert.position, world, bestDistance, best, found);
            break;
         }
         case entityLeader:
         {
            LeaderEntity leader = (LeaderEntity)entity;
            uint c;
            if(leader.pointCount && leader.points)
            {
               for(c = 0; c < leader.pointCount; c++)
                  ConsiderSnap(leader.points[c], world, bestDistance, best, found);
               for(c = 0; c + 1 < leader.pointCount; c++)
               {
                  VectorPoint mid = MidPoint(leader.points[c], leader.points[c + 1]);
                  ConsiderSnap(mid, world, bestDistance, best, found);
               }
            }
            break;
         }
         case entityHatch:
         {
            HatchEntity hatch = (HatchEntity)entity;
            uint c, segCount;
            if(hatch.boundaryPointCount && hatch.boundaryPoints)
            {
               for(c = 0; c < hatch.boundaryPointCount; c++)
                  ConsiderSnap(hatch.boundaryPoints[c], world, bestDistance, best, found);
               segCount = hatch.boundaryPointCount;
               for(c = 0; c < segCount; c++)
               {
                  uint next = (c + 1) % hatch.boundaryPointCount;
                  VectorPoint mid = MidPoint(hatch.boundaryPoints[c], hatch.boundaryPoints[next]);
                  ConsiderSnap(mid, world, bestDistance, best, found);
               }
            }
            else
               ConsiderSnap(hatch.seed, world, bestDistance, best, found);
            break;
         }
         case entityDimension:
         {
            DimensionEntity dim = (DimensionEntity)entity;
            VectorPoint dim1, dim2;
            dim.ProjectDimPoints(&dim1, &dim2);
            ConsiderSnap(dim.defPoint, world, bestDistance, best, found);
            ConsiderSnap(dim.extLine1, world, bestDistance, best, found);
            ConsiderSnap(dim.extLine2, world, bestDistance, best, found);
            ConsiderSnap(dim1, world, bestDistance, best, found);
            ConsiderSnap(dim2, world, bestDistance, best, found);
            {
               VectorPoint mid = MidPoint(dim1, dim2);
               ConsiderSnap(mid, world, bestDistance, best, found);
            }
            ConsiderSnap(dim.textMidPoint, world, bestDistance, best, found);
            break;
         }
      }
   }

   void FillGripPoints(SemanticEntity entity, InteractionPoint * points, VectorBounds * bounds)
   {
      uint index = 0;

      if(!entity || !points || !bounds)
         return;

      (*bounds).Reset();

      switch(entity.type)
      {
         case entityLine:
         {
            LineEntity line = (LineEntity)entity;
            AddGrip(points, &index, line.start);
            AddGrip(points, &index, line.end);
            break;
         }
         case entityCircle:
         {
            CircleEntity circle = (CircleEntity)entity;
            VectorPoint east = { circle.center.x + circle.radius, circle.center.y, circle.center.z };
            AddGrip(points, &index, circle.center);
            AddGrip(points, &index, east);
            break;
         }
         case entityArc:
         {
            ArcEntity arc = (ArcEntity)entity;
            VectorPoint startPt = ArcEndpoint(arc.center, arc.radius, arc.startAngle);
            VectorPoint endPt = ArcEndpoint(arc.center, arc.radius, arc.endAngle);
            AddGrip(points, &index, arc.center);
            AddGrip(points, &index, startPt);
            AddGrip(points, &index, endPt);
            break;
         }
         case entityEllipse:
         {
            EllipseEntity ellipse = (EllipseEntity)entity;
            VectorPoint axis = { ellipse.center.x + ellipse.radiusX, ellipse.center.y, ellipse.center.z };
            AddGrip(points, &index, ellipse.center);
            AddGrip(points, &index, axis);
            break;
         }
         case entityPolyline:
         {
            PolylineEntity poly = (PolylineEntity)entity;
            uint c;
            for(c = 0; c < poly.pointCount; c++)
               AddGrip(points, &index, poly.points[c]);
            break;
         }
         case entitySpline:
         {
            SplineEntity spline = (SplineEntity)entity;
            uint c;
            for(c = 0; c < spline.controlPointCount; c++)
               AddGrip(points, &index, spline.controlPoints[c]);
            break;
         }
         case entityText:
         {
            TextEntity text = (TextEntity)entity;
            AddGrip(points, &index, text.position);
            break;
         }
         case entityInsert:
         {
            InsertEntity insert = (InsertEntity)entity;
            AddGrip(points, &index, insert.position);
            break;
         }
         case entityLeader:
         {
            LeaderEntity leader = (LeaderEntity)entity;
            uint c;
            for(c = 0; c < leader.pointCount; c++)
               AddGrip(points, &index, leader.points[c]);
            break;
         }
         case entityHatch:
         {
            HatchEntity hatch = (HatchEntity)entity;
            if(hatch.boundaryPointCount)
            {
               uint c;
               for(c = 0; c < hatch.boundaryPointCount; c++)
                  AddGrip(points, &index, hatch.boundaryPoints[c]);
            }
            else
               AddGrip(points, &index, hatch.seed);
            break;
         }
         case entityDimension:
         {
            DimensionEntity dim = (DimensionEntity)entity;
            AddGrip(points, &index, dim.extLine1);
            AddGrip(points, &index, dim.extLine2);
            AddGrip(points, &index, dim.dimLinePoint);
            AddGrip(points, &index, dim.textMidPoint);
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
         FillGripPoints(entity, overlay.points, &overlay.selectionBounds);

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

   public bool PickSnap(CADDocument doc, VectorPoint world, double tolerance, InteractionPoint * result)
   {
      Link link;
      double bestDistance = tolerance;
      bool found = false;
      InteractionPoint best;
      best.kind = snap;
      best.point = { 0, 0, 0 };

      if(!doc || tolerance <= 0 || !result)
         return false;

      for(link = doc.entities.first; link; link = link.next)
      {
         SemanticEntity entity = (SemanticEntity)doc.entities.GetData(link);
         CollectEntitySnapPoints(entity, world, tolerance, &best, &bestDistance, &found);
      }

      if(found)
      {
         (*result).kind = best.kind;
         (*result).point = best.point;
      }
      return found;
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
         case entityDimension:
         {
            DimensionEntity dim = (DimensionEntity)entity;
            if(gripIndex == 0)
               dim.extLine1 = newPoint;
            else if(gripIndex == 1)
               dim.extLine2 = newPoint;
            else if(gripIndex == 2)
               dim.dimLinePoint = newPoint;
            else if(gripIndex == 3)
            {
               dim.textMidPoint = newPoint;
               dim.defPoint = newPoint;
            }
            else
               return false;
            dim.Touch();
            break;
         }
         default:
            return false;
      }

      return true;
   }
};
