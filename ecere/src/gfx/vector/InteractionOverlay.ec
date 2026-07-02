namespace gfx::vector;

import "Geometry"

public enum InteractionPointKind
{
   grip,
   snap,
   constraint
};

public struct InteractionPoint
{
   InteractionPointKind kind;
   VectorPoint point;
};

public class InteractionOverlay
{
public:
   uint64 ownerEntityId;
   VectorBounds selectionBounds;
   uint pointCount;
   InteractionPoint * points;

   ~InteractionOverlay()
   {
      delete points;
   }
};
