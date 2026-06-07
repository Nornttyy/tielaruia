# 共享常量, 避免循环引用
extends RefCounted
class_name ChunkConstants

const CHUNK_WIDTH := 64
const WORLD_HEIGHT := 256
const VIEW_RADIUS := 2
const TILE_SIZE := 6   # 方块像素尺寸 (单一来源). 12→6 全局缩小, 改这一个数即可
