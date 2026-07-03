namespace gfx::vector;

import "ecere"
import "Geometry"
import "CADDocument"

// Phase 2: ASCII DXF import into the semantic CAD model (CADDocument).
// Supported entities: LINE, CIRCLE, ARC, ELLIPSE, LWPOLYLINE, POLYLINE/VERTEX,
// TEXT, MTEXT, INSERT, BLOCK/ENDBLK (block definitions), HATCH (solid/polyline boundary),
// DIMENSION (linear aligned, simplified).
public class DXFReader
{
   CADDocument document;
   BlockDefinition currentBlock;
   bool inBlockDefinition;
   bool inPolyline;
   PolylineEntity polylineEntity;
   HatchEntity hatchEntity;
   bool inHatch;
   bool hatchCollectBoundary;
   bool hatchGotSeed;
   bool hatchHavePendingX;
   double hatchSeedX, hatchSeedY, hatchSeedZ;
   double hatchPendingX, hatchPendingY, hatchPendingZ;
   char layer[256];
   int color;
   char lastError[512];

   bool ReadPair(File f, int * code, char * value, int valueSize)
   {
      char line[256];
      if(!f || !code || !value)
         return false;
      if(!f.GetLine(line, sizeof(line)))
         return false;
      (*code) = atoi(line);
      if(!f.GetLine(value, valueSize))
         return false;
      return true;
   }

   double ParseDouble(const char * value)
   {
      return ParseDXFDouble(value);
   }

   void ResetEntityDefaults()
   {
      strcpy(layer, "0");
      color = 256;
   }

   void ApplyCommonProperties(SemanticEntity entity)
   {
      if(entity)
      {
         delete entity.layer;
         entity.layer = CopyString(layer);
         entity.color = color;
      }
   }

   SemanticEntity AddToTarget(SemanticEntity entity)
   {
      ApplyCommonProperties(entity);
      if(inBlockDefinition && currentBlock)
         return currentBlock.AddEntity(entity);
      return document ? document.AddEntity(entity) : entity;
   }

   void BeginBlock(const char * name)
   {
      if(document)
      {
         currentBlock = document.AddBlock(name ? name : "");
         inBlockDefinition = true;
      }
   }

   void EndBlock()
   {
      inBlockDefinition = false;
      currentBlock = null;
   }

   void BeginPolyline(bool closed)
   {
      FinishPolyline();
      inPolyline = true;
      polylineEntity = { };
      polylineEntity.type = entityPolyline;
      polylineEntity.closed = closed;
   }

   void AddPolylineVertex(double x, double y, double z, double bulge)
   {
      uint index;
      VectorPoint * points;
      double * bulges;
      uint segmentCount;

      if(!inPolyline)
         return;

      index = polylineEntity.pointCount;
      points = polylineEntity.pointCount ? new VectorPoint[polylineEntity.pointCount + 1] : new VectorPoint[1];
      if(polylineEntity.points)
      {
         memcpy(points, polylineEntity.points, sizeof(VectorPoint) * polylineEntity.pointCount);
         delete polylineEntity.points;
      }
      points[index] = { x, y, z };
      polylineEntity.points = points;
      polylineEntity.pointCount = index + 1;

      if(!VectorIsZero(bulge, VECTOR_BULGE_EPSILON) && polylineEntity.pointCount > 1)
      {
         segmentCount = polylineEntity.pointCount - 1;
         bulges = new double[segmentCount];
         if(polylineEntity.bulges)
         {
            memcpy(bulges, polylineEntity.bulges, sizeof(double) * (segmentCount - 1));
            delete polylineEntity.bulges;
         }
         bulges[segmentCount - 1] = bulge;
         polylineEntity.bulges = bulges;
      }
   }

   void FinishPolyline()
   {
      PolylineEntity entity;
      if(inPolyline)
      {
         entity = polylineEntity;
         polylineEntity = { };
         inPolyline = false;
         if(entity.pointCount)
            AddToTarget(entity);
         else
         {
            delete entity.points;
            delete entity.bulges;
         }
      }
   }

   void BeginHatch()
   {
      FinishHatch();
      inHatch = true;
      hatchCollectBoundary = hatchGotSeed = hatchHavePendingX = false;
      hatchSeedX = hatchSeedY = hatchSeedZ = 0;
      hatchPendingX = hatchPendingY = hatchPendingZ = 0;
      hatchEntity = { };
      hatchEntity.type = entityHatch;
   }

   void AddHatchBoundaryVertex(double x, double y, double z)
   {
      uint index;
      VectorPoint * points;

      if(!inHatch)
         return;

      index = hatchEntity.boundaryPointCount;
      points = hatchEntity.boundaryPointCount ? new VectorPoint[hatchEntity.boundaryPointCount + 1] : new VectorPoint[1];
      if(hatchEntity.boundaryPoints)
      {
         memcpy(points, hatchEntity.boundaryPoints, sizeof(VectorPoint) * hatchEntity.boundaryPointCount);
         delete hatchEntity.boundaryPoints;
      }
      points[index] = { x, y, z };
      hatchEntity.boundaryPoints = points;
      hatchEntity.boundaryPointCount = index + 1;
   }

   void FinishHatch()
   {
      HatchEntity entity;
      bool hadSeed;
      if(inHatch)
      {
         if(hatchHavePendingX)
         {
            hatchHavePendingX = false;
            AddHatchBoundaryVertex(hatchPendingX, hatchPendingY, hatchPendingZ);
         }

         hadSeed = hatchGotSeed;
         entity = hatchEntity;
         hatchEntity = { };
         inHatch = hatchCollectBoundary = hatchGotSeed = false;

         entity.seed = { hatchSeedX, hatchSeedY, hatchSeedZ };
         if(entity.boundaryPointCount >= 3 || hadSeed)
            AddToTarget(entity);
         else
         {
            delete entity.boundaryPoints;
            delete entity.name;
            delete entity.hPattern;
         }
      }
   }

   void FinalizeEntity(const char * entityType,
      double x1, double y1, double z1, double x2, double y2, double z2,
      double cx, double cy, double cz, double radius, double startAngle, double endAngle,
      double majorX, double majorY, double majorZ, double ratio,
      const char * textValue, const char * blockName,
      double xScale, double yScale, double zScale, double angle, double height)
   {
      if(!entityType || !entityType[0])
         return;

      if(!strcmp(entityType, "LINE"))
      {
         LineEntity entity { start = { x1, y1, z1 }, end = { x2, y2, z2 } };
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "CIRCLE"))
      {
         CircleEntity entity { center = { cx, cy, cz }, radius = radius };
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "ARC"))
      {
         ArcEntity entity { center = { cx, cy, cz }, radius = radius, startAngle = startAngle, endAngle = endAngle };
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "ELLIPSE"))
      {
         double majorLen = sqrt(majorX * majorX + majorY * majorY + majorZ * majorZ);
         double rot = majorLen > 0 ? VectorRadiansToDegrees(atan2(majorY, majorX)) : 0;
         EllipseEntity entity
         {
            center = { cx, cy, cz },
            radiusX = majorLen,
            radiusY = majorLen * ratio,
            rotation = rot
         };
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "TEXT") || !strcmp(entityType, "MTEXT"))
      {
         TextEntity entity { position = { x1, y1, z1 }, alignment = { x1, y1, z1 }, height = height > 0 ? height : 1, angle = angle };
         entity.SetText(textValue);
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "INSERT"))
      {
         InsertEntity entity { position = { x1, y1, z1 }, xScale = xScale, yScale = yScale, zScale = zScale, angle = angle };
         entity.SetName(blockName);
         AddToTarget(entity);
      }
      else if(!strcmp(entityType, "BLOCK"))
      {
         BeginBlock(blockName);
      }
   }

   void FinalizeDimension(
      double defX, double defY, double defZ,
      double textX, double textY, double textZ,
      double dimX, double dimY, double dimZ,
      double ext1X, double ext1Y, double ext1Z,
      double ext2X, double ext2Y, double ext2Z,
      const char * textValue, double textHeight, int dimType)
   {
      DimensionEntity entity
      {
         defPoint = { defX, defY, defZ },
         textMidPoint = { textX, textY, textZ },
         dimLinePoint = { dimX, dimY, dimZ },
         extLine1 = { ext1X, ext1Y, ext1Z },
         extLine2 = { ext2X, ext2Y, ext2Z },
         dimType = dimType,
         textHeight = textHeight > 0 ? textHeight : 2.5
      };
      entity.SetText(textValue);
      AddToTarget(entity);
   }

   bool Load(CADDocument target, const char * fileName)
   {
      File f { };
      int code;
      char value[4096];
      char entityType[64];
      bool inEntities = false;
      bool inBlocks = false;
      double x1 = 0, y1 = 0, z1 = 0, x2 = 0, y2 = 0, z2 = 0;
      double cx = 0, cy = 0, cz = 0, radius = 0, startAngle = 0, endAngle = 0;
      double majorX = 0, majorY = 0, majorZ = 0, ratio = 1;
      char textValue[1024];
      char blockName[256];
      double xScale = 1, yScale = 1, zScale = 1, angle = 0, height = 0;
      bool polylineClosed = false;
      double bulge = 0;
      double pendingX = 0, pendingY = 0, pendingZ = 0;
      bool havePendingX = false;
      double dimExt2X = 0, dimExt2Y = 0, dimExt2Z = 0;
      int dimType = 0;
      int pairCount = 0;

      entityType[0] = 0;
      textValue[0] = 0;
      blockName[0] = 0;
      lastError[0] = 0;
      document = target;
      inBlockDefinition = inPolyline = inHatch = false;
      currentBlock = null;
      polylineEntity = { };
      hatchEntity = { };
      hatchCollectBoundary = hatchGotSeed = hatchHavePendingX = false;

      if(!document || !fileName || !fileName[0])
      {
         strcpy(lastError, "Missing document or file name");
         return false;
      }

      if(!(f = FileOpen(fileName, read)))
      {
         sprintf(lastError, "Unable to open file: %s", fileName);
         return false;
      }

      while(ReadPair(f, &code, value, sizeof(value)))
      {
         pairCount++;

         if(code == 0)
         {
            if(entityType[0])
            {
               if(!strcmp(entityType, "LWPOLYLINE") || !strcmp(entityType, "POLYLINE"))
                  FinishPolyline();
               else if(!strcmp(entityType, "HATCH"))
                  FinishHatch();
               else if(!strcmp(entityType, "ENDBLK"))
                  EndBlock();
               else if(!strcmp(entityType, "DIMENSION"))
                  FinalizeDimension(
                     x1, y1, z1, x2, y2, z2, cx, cy, cz,
                     majorX, majorY, majorZ, dimExt2X, dimExt2Y, dimExt2Z,
                     textValue, height, dimType);
               else
                  FinalizeEntity(entityType,
                     x1, y1, z1, x2, y2, z2,
                     cx, cy, cz, radius, startAngle, endAngle,
                     majorX, majorY, majorZ, ratio,
                     textValue, blockName,
                     xScale, yScale, zScale, angle, height);
            }

            strncpy(entityType, value, sizeof(entityType) - 1);
            entityType[sizeof(entityType) - 1] = 0;

            if(!strcmp(value, "SECTION"))
               inEntities = inBlocks = false;
            else if(!strcmp(value, "ENDSEC"))
            {
               FinishPolyline();
               FinishHatch();
               inEntities = inBlocks = false;
            }
            else if(!strcmp(value, "EOF"))
               break;

            x1 = y1 = z1 = x2 = y2 = z2 = 0;
            cx = cy = cz = radius = startAngle = endAngle = 0;
            majorX = majorY = majorZ = 0;
            ratio = 1;
            textValue[0] = 0;
            blockName[0] = 0;
            xScale = yScale = zScale = 1;
            angle = height = 0;
            bulge = 0;
            polylineClosed = false;
            havePendingX = false;
            dimExt2X = dimExt2Y = dimExt2Z = 0;
            dimType = 0;

            if(!strcmp(value, "POLYLINE") || !strcmp(value, "LWPOLYLINE"))
            {
               ResetEntityDefaults();
               BeginPolyline(polylineClosed);
            }
            else if(!strcmp(value, "HATCH"))
            {
               ResetEntityDefaults();
               BeginHatch();
            }
            else if(!strcmp(value, "LINE") || !strcmp(value, "CIRCLE") || !strcmp(value, "ARC") ||
                    !strcmp(value, "ELLIPSE") || !strcmp(value, "TEXT") || !strcmp(value, "MTEXT") ||
                    !strcmp(value, "INSERT") || !strcmp(value, "BLOCK") || !strcmp(value, "DIMENSION"))
               ResetEntityDefaults();
            else if(!strcmp(value, "VERTEX"))
            {
               if(havePendingX)
                  AddPolylineVertex(pendingX, pendingY, pendingZ, bulge);
               pendingX = pendingY = pendingZ = 0;
               bulge = 0;
               havePendingX = false;
            }

            continue;
         }

         if(code == 2)
         {
            if(!strcmp(value, "ENTITIES"))
               inEntities = true;
            else if(!strcmp(value, "BLOCKS"))
               inBlocks = true;
            else if(inHatch && entityType[0] && !strcmp(entityType, "HATCH"))
               hatchEntity.SetHPattern(value);
            else if(entityType[0] && (!strcmp(entityType, "BLOCK") || !strcmp(entityType, "INSERT")))
            {
               strncpy(blockName, value, sizeof(blockName) - 1);
               blockName[sizeof(blockName) - 1] = 0;
            }
            continue;
         }

         if(!inEntities && !inBlocks && !inBlockDefinition)
            continue;

         if(!entityType[0])
            continue;

         switch(code)
         {
            case 8:
               if(value)
               {
                  strncpy(layer, value, sizeof(layer) - 1);
                  layer[sizeof(layer) - 1] = 0;
               }
               break;
            case 62: color = atoi(value); break;
            case 1:
               if(value)
               {
                  strncpy(textValue, value, sizeof(textValue) - 1);
                  textValue[sizeof(textValue) - 1] = 0;
               }
               break;
            case 10:
               if(inHatch)
               {
                  if(hatchCollectBoundary)
                  {
                     if(hatchHavePendingX)
                        AddHatchBoundaryVertex(hatchPendingX, hatchPendingY, hatchPendingZ);
                     hatchPendingX = ParseDouble(value);
                     hatchPendingY = hatchPendingZ = 0;
                     hatchHavePendingX = true;
                  }
                  else if(!hatchGotSeed)
                     hatchSeedX = ParseDouble(value);
               }
               else if(inPolyline)
               {
                  if(havePendingX)
                     AddPolylineVertex(pendingX, pendingY, pendingZ, bulge);
                  pendingX = ParseDouble(value);
                  pendingY = pendingZ = 0;
                  bulge = 0;
                  havePendingX = true;
               }
               else if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  x1 = ParseDouble(value);
               else
                  x1 = cx = ParseDouble(value);
               break;
            case 11:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  x2 = ParseDouble(value);
               else
                  x2 = majorX = ParseDouble(value);
               break;
            case 12:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  cx = ParseDouble(value);
               break;
            case 13:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  majorX = ParseDouble(value);
               break;
            case 14:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  dimExt2X = ParseDouble(value);
               break;
            case 20:
               if(inHatch)
               {
                  if(hatchCollectBoundary && hatchHavePendingX)
                  {
                     hatchPendingY = ParseDouble(value);
                     AddHatchBoundaryVertex(hatchPendingX, hatchPendingY, hatchPendingZ);
                     hatchHavePendingX = false;
                  }
                  else if(!hatchGotSeed)
                  {
                     hatchSeedY = ParseDouble(value);
                     hatchGotSeed = true;
                  }
               }
               else if(inPolyline && havePendingX)
               {
                  pendingY = ParseDouble(value);
                  AddPolylineVertex(pendingX, pendingY, pendingZ, bulge);
                  havePendingX = false;
                  bulge = 0;
               }
               else if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  y1 = ParseDouble(value);
               else
                  y1 = cy = ParseDouble(value);
               break;
            case 21:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  y2 = ParseDouble(value);
               else
                  y2 = majorY = ParseDouble(value);
               break;
            case 22:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  cy = ParseDouble(value);
               break;
            case 23:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  majorY = ParseDouble(value);
               break;
            case 24:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  dimExt2Y = ParseDouble(value);
               break;
            case 30:
               if(inHatch && hatchCollectBoundary && hatchHavePendingX)
                  hatchPendingZ = ParseDouble(value);
               else if(inPolyline && havePendingX)
                  pendingZ = ParseDouble(value);
               else if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  z1 = ParseDouble(value);
               else
                  z1 = cz = ParseDouble(value);
               break;
            case 31:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  z2 = ParseDouble(value);
               else
                  z2 = majorZ = ParseDouble(value);
               break;
            case 32:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  cz = ParseDouble(value);
               break;
            case 33:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  majorZ = ParseDouble(value);
               break;
            case 34:
               if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  dimExt2Z = ParseDouble(value);
               break;
            case 40:
               if(!strcmp(entityType, "TEXT") || !strcmp(entityType, "MTEXT") || !strcmp(entityType, "DIMENSION"))
                  height = ParseDouble(value);
               else if(!strcmp(entityType, "ELLIPSE"))
                  ratio = ParseDouble(value);
               else if(inHatch)
                  hatchEntity.scale = ParseDouble(value);
               else
                  radius = ParseDouble(value);
               break;
            case 41:
               if(inHatch)
                  hatchEntity.scale = ParseDouble(value);
               else
                  xScale = ParseDouble(value);
               break;
            case 42:
               if(inPolyline)
                  bulge = ParseDouble(value);
               else
                  yScale = ParseDouble(value);
               break;
            case 43: zScale = ParseDouble(value); break;
            case 50:
               if(!strcmp(entityType, "TEXT") || !strcmp(entityType, "MTEXT"))
                  angle = ParseDouble(value);
               else if(inHatch)
                  hatchEntity.angle = ParseDouble(value);
               else
                  startAngle = ParseDouble(value);
               break;
            case 52:
               if(inHatch)
                  hatchEntity.angle = ParseDouble(value);
               break;
            case 51: endAngle = ParseDouble(value); break;
            case 70:
               if(inHatch)
                  hatchEntity.solid = atoi(value) != 0;
               else if(entityType[0] && !strcmp(entityType, "DIMENSION"))
                  dimType = atoi(value);
               else
               {
                  polylineClosed = (atoi(value) & 1) != 0;
                  if(inPolyline)
                     polylineEntity.closed = polylineClosed;
               }
               break;
            case 93:
               if(inHatch && atoi(value) > 0)
                  hatchCollectBoundary = true;
               break;
         }
      }

      if(entityType[0])
      {
         if(!strcmp(entityType, "LWPOLYLINE") || !strcmp(entityType, "POLYLINE"))
            FinishPolyline();
         else if(!strcmp(entityType, "HATCH"))
            FinishHatch();
         else if(!strcmp(entityType, "ENDBLK"))
            EndBlock();
         else if(!strcmp(entityType, "DIMENSION"))
            FinalizeDimension(
               x1, y1, z1, x2, y2, z2, cx, cy, cz,
               majorX, majorY, majorZ, dimExt2X, dimExt2Y, dimExt2Z,
               textValue, height, dimType);
         else
            FinalizeEntity(entityType,
               x1, y1, z1, x2, y2, z2,
               cx, cy, cz, radius, startAngle, endAngle,
               majorX, majorY, majorZ, ratio,
               textValue, blockName,
               xScale, yScale, zScale, angle, height);
      }

      delete f;

      if(pairCount < 2)
      {
         strcpy(lastError, "File does not look like a DXF (too few group pairs)");
         return false;
      }

      document.RebuildSemanticDisplayLines();
      return true;
   }

   const char * GetLastError()
   {
      return lastError;
   }
}
