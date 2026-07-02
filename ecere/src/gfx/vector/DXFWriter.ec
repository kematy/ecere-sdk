namespace gfx::vector;

import "Geometry"
import "CADDocument"

// Phase 3: ASCII DXF export from the semantic CAD model (CADDocument).
// Writes the same entity subset supported by DXFReader for round-trip use.
public class DXFWriter
{
   char lastError[512];

   void WritePairInt(File f, int code, int value)
   {
      f.PrintLn("%d", code);
      f.PrintLn("%d", value);
   }

   void WritePairDouble(File f, int code, double value)
   {
      char buffer[64];
      FormatDXFDouble(buffer, sizeof(buffer), value);
      f.PrintLn("%d", code);
      f.PrintLn("%s", buffer);
   }

   void WritePairString(File f, int code, const char * value)
   {
      f.PrintLn("%d", code);
      f.PrintLn("%s", value ? value : "");
   }

   void WriteCommonProperties(File f, SemanticEntity entity)
   {
      if(entity)
      {
         WritePairString(f, 8, entity.layer ? entity.layer : "0");
         if(entity.color != 256)
            WritePairInt(f, 62, entity.color);
      }
   }

   void WriteLine(File f, LineEntity entity)
   {
      WritePairString(f, 0, "LINE");
      WriteCommonProperties(f, entity);
      WritePairDouble(f, 10, entity.start.x);
      WritePairDouble(f, 20, entity.start.y);
      WritePairDouble(f, 30, entity.start.z);
      WritePairDouble(f, 11, entity.end.x);
      WritePairDouble(f, 21, entity.end.y);
      WritePairDouble(f, 31, entity.end.z);
   }

   void WriteCircle(File f, CircleEntity entity)
   {
      WritePairString(f, 0, "CIRCLE");
      WriteCommonProperties(f, entity);
      WritePairDouble(f, 10, entity.center.x);
      WritePairDouble(f, 20, entity.center.y);
      WritePairDouble(f, 30, entity.center.z);
      WritePairDouble(f, 40, entity.radius);
   }

   void WriteArc(File f, ArcEntity entity)
   {
      WritePairString(f, 0, "ARC");
      WriteCommonProperties(f, entity);
      WritePairDouble(f, 10, entity.center.x);
      WritePairDouble(f, 20, entity.center.y);
      WritePairDouble(f, 30, entity.center.z);
      WritePairDouble(f, 40, entity.radius);
      WritePairDouble(f, 50, entity.startAngle);
      WritePairDouble(f, 51, entity.endAngle);
   }

   void WriteEllipse(File f, EllipseEntity entity)
   {
      double rot = VectorDegreesToRadians(entity.rotation);
      double majorX = entity.radiusX * cos(rot);
      double majorY = entity.radiusX * sin(rot);
      double ratio = entity.radiusX > 0 ? entity.radiusY / entity.radiusX : 1;

      WritePairString(f, 0, "ELLIPSE");
      WriteCommonProperties(f, entity);
      WritePairDouble(f, 10, entity.center.x);
      WritePairDouble(f, 20, entity.center.y);
      WritePairDouble(f, 30, entity.center.z);
      WritePairDouble(f, 11, majorX);
      WritePairDouble(f, 21, majorY);
      WritePairDouble(f, 31, 0);
      WritePairDouble(f, 40, ratio);
   }

   void WritePolyline(File f, PolylineEntity entity)
   {
      uint c;
      WritePairString(f, 0, "LWPOLYLINE");
      WriteCommonProperties(f, entity);
      WritePairInt(f, 90, (int)entity.pointCount);
      if(entity.closed)
         WritePairInt(f, 70, 1);

      for(c = 0; c < entity.pointCount; c++)
      {
         uint segCount = entity.closed ? entity.pointCount : (entity.pointCount > 1 ? entity.pointCount - 1 : 0);

         WritePairDouble(f, 10, entity.points[c].x);
         WritePairDouble(f, 20, entity.points[c].y);
         if(!VectorIsZero(entity.points[c].z, VECTOR_COORD_EPSILON))
            WritePairDouble(f, 30, entity.points[c].z);
         if(entity.bulges && c < segCount && !VectorIsZero(entity.bulges[c], VECTOR_BULGE_EPSILON))
            WritePairDouble(f, 42, entity.bulges[c]);
      }
   }

   void WriteSplineAsPolyline(File f, SplineEntity entity)
   {
      PolylineEntity poly { };
      poly.type = entityPolyline;
      poly.closed = entity.closed;
      poly.SetPoints(entity.controlPoints, entity.controlPointCount);
      WritePolyline(f, poly);
      delete poly.points;
   }

   void WriteText(File f, TextEntity entity)
   {
      WritePairString(f, 0, "TEXT");
      WriteCommonProperties(f, entity);
      WritePairDouble(f, 10, entity.position.x);
      WritePairDouble(f, 20, entity.position.y);
      WritePairDouble(f, 30, entity.position.z);
      WritePairDouble(f, 40, entity.height);
      if(!VectorIsZero(entity.angle, VECTOR_COORD_EPSILON))
         WritePairDouble(f, 50, entity.angle);
      WritePairString(f, 1, entity.text ? entity.text : "");
   }

   void WriteInsert(File f, InsertEntity entity)
   {
      WritePairString(f, 0, "INSERT");
      WriteCommonProperties(f, entity);
      WritePairString(f, 2, entity.name ? entity.name : "");
      WritePairDouble(f, 10, entity.position.x);
      WritePairDouble(f, 20, entity.position.y);
      WritePairDouble(f, 30, entity.position.z);
      if(!VectorIsZero(entity.xScale - 1, VECTOR_COORD_EPSILON)) WritePairDouble(f, 41, entity.xScale);
      if(!VectorIsZero(entity.yScale - 1, VECTOR_COORD_EPSILON)) WritePairDouble(f, 42, entity.yScale);
      if(!VectorIsZero(entity.zScale - 1, VECTOR_COORD_EPSILON)) WritePairDouble(f, 43, entity.zScale);
      if(!VectorIsZero(entity.angle, VECTOR_COORD_EPSILON)) WritePairDouble(f, 50, entity.angle);
   }

   void WriteLeaderAsPolyline(File f, LeaderEntity entity)
   {
      PolylineEntity poly { };
      poly.type = entityPolyline;
      poly.closed = false;
      poly.SetPoints(entity.points, entity.pointCount);
      WritePolyline(f, poly);
      delete poly.points;
   }

   void WriteEntity(File f, SemanticEntity entity)
   {
      if(!entity)
         return;

      switch(entity.type)
      {
         case entityLine: WriteLine(f, (LineEntity)entity); break;
         case entityCircle: WriteCircle(f, (CircleEntity)entity); break;
         case entityArc: WriteArc(f, (ArcEntity)entity); break;
         case entityEllipse: WriteEllipse(f, (EllipseEntity)entity); break;
         case entityPolyline: WritePolyline(f, (PolylineEntity)entity); break;
         case entitySpline: WriteSplineAsPolyline(f, (SplineEntity)entity); break;
         case entityText: WriteText(f, (TextEntity)entity); break;
         case entityInsert: WriteInsert(f, (InsertEntity)entity); break;
         case entityLeader: WriteLeaderAsPolyline(f, (LeaderEntity)entity); break;
         default: break;
      }
   }

   void WriteEntities(File f, List<SemanticEntity> entities)
   {
      Link link;
      for(link = entities.first; link; link = link.next)
      {
         SemanticEntity entity = (SemanticEntity)entities.GetData(link);
         WriteEntity(f, entity);
      }
   }

   void WriteBlocksSection(File f, CADDocument document)
   {
      Link link;

      WritePairString(f, 0, "SECTION");
      WritePairString(f, 2, "BLOCKS");

      for(link = document.blocks.first; link; link = link.next)
      {
         BlockDefinition block = (BlockDefinition)document.blocks.GetData(link);
         if(!block)
            continue;

         WritePairString(f, 0, "BLOCK");
         WritePairString(f, 8, "0");
         WritePairString(f, 2, block.name ? block.name : "");
         WritePairDouble(f, 10, 0);
         WritePairDouble(f, 20, 0);
         WritePairDouble(f, 30, 0);
         WriteEntities(f, block.entities);
         WritePairString(f, 0, "ENDBLK");
      }

      WritePairString(f, 0, "ENDSEC");
   }

   void WriteEntitiesSection(File f, CADDocument document)
   {
      WritePairString(f, 0, "SECTION");
      WritePairString(f, 2, "ENTITIES");
      WriteEntities(f, document.entities);
      WritePairString(f, 0, "ENDSEC");
   }

   void WriteHeaderSection(File f)
   {
      WritePairString(f, 0, "SECTION");
      WritePairString(f, 2, "HEADER");
      WritePairString(f, 9, "$ACADVER");
      WritePairString(f, 1, "AC1015");
      WritePairString(f, 9, "$LUPREC");
      WritePairInt(f, 70, VECTOR_DXF_DECIMALS);
      WritePairString(f, 9, "$AUPREC");
      WritePairInt(f, 70, VECTOR_DXF_DECIMALS);
      WritePairString(f, 0, "ENDSEC");
   }

   bool Save(CADDocument document, const char * fileName)
   {
      File f { };

      lastError[0] = 0;

      if(!document || !fileName || !fileName[0])
      {
         strcpy(lastError, "Missing document or file name");
         return false;
      }

      if(!f.Open(fileName, write))
      {
         sprintf(lastError, "Unable to create file: %s", fileName);
         return false;
      }

      WriteHeaderSection(f);
      if(document.blocks.count)
         WriteBlocksSection(f);
      WriteEntitiesSection(f);
      WritePairString(f, 0, "EOF");

      f.Close();
      return true;
   }

   const char * GetLastError()
   {
      return lastError;
   }
}
