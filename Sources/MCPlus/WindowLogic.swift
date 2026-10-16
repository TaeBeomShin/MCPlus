import Foundation
import CoreGraphics

struct WindowIdentity: Equatable {
    let id: UInt32?
    let pid: Int32
    let title: String
}

struct WindowServerRecord {
    let identity: WindowIdentity
    let frame: CGRect
    let layer: Int
    let onScreen: Bool
}

enum WindowServerMatching {
    // During Mission Control, WindowServer reports the transformed bounds of the
    // real window. Require exact bounds and a single live application-window ID;
    // neither nearest-neighbour geometry nor title ordering establishes identity.
    static func identity(for frame: CGRect, title: String, pid: Int32, in records: [WindowServerRecord], validatedWindows: [WindowIdentity] = []) -> WindowIdentity? {
        guard frame.width > 1, frame.height > 1,
              [frame.minX,frame.minY,frame.width,frame.height].allSatisfy({ $0.isFinite }) else { return nil }
        let matches=records.filter { $0.onScreen && $0.layer == 0 && $0.frame == frame }
        guard matches.count == 1, let match=matches.first,
              let id=match.identity.id,id != 0,match.identity.pid > 0,
              pid <= 0 || match.identity.pid == pid else { return nil }
        // Captions from Mission Control, AXWindow, and WindowServer can differ.
        // A conflicting caption needs the stronger independent AX ID/PID binding;
        // otherwise retain the conservative title check.
        if !title.isEmpty && !match.identity.title.isEmpty && title != match.identity.title,
           WindowMatching.index(for:match.identity,in:validatedWindows)==nil { return nil }
        return match.identity
    }
}

enum WindowMatching {
    // A caption is not an identity: a closed thumbnail may outlive its window,
    // at which point a formerly ambiguous title can become "unique" on another window.
    static func index(for thumbnail: WindowIdentity, in windows: [WindowIdentity]) -> Int? {
        if let id = thumbnail.id, id != 0 {
            let matches = windows.indices.filter { windows[$0].id == id && (thumbnail.pid <= 0 || windows[$0].pid == thumbnail.pid) }
            return matches.count == 1 ? matches[0] : nil
        }
        return nil
    }
}

enum Direction: Equatable { case left, right, up, down }

enum WindowNavigation {
    static func next(from index: Int, frames: [CGRect], direction: Direction) -> Int? {
        guard frames.indices.contains(index) else { return frames.isEmpty ? nil : 0 }
        let origin = CGPoint(x: frames[index].midX, y: frames[index].midY)
        return frames.indices.filter { $0 != index }.compactMap { candidate -> (Int, CGFloat)? in
            let dx = frames[candidate].midX - origin.x
            let dy = frames[candidate].midY - origin.y // AX uses top-left origin.
            let forward: CGFloat
            let sideways: CGFloat
            switch direction {
            case .left: forward = -dx; sideways = abs(dy)
            case .right: forward = dx; sideways = abs(dy)
            case .up: forward = -dy; sideways = abs(dx)
            case .down: forward = dy; sideways = abs(dx)
            }
            guard forward > 1 else { return nil }
            return (candidate, hypot(dx, dy) + sideways * 2)
        }.min { $0.1 < $1.1 }?.0
    }

    static func orderedIndices(_ frames: [CGRect]) -> [Int] {
        let vertical=frames.indices.sorted { frames[$0].minY == frames[$1].minY ? $0 < $1 : frames[$0].minY < frames[$1].minY }
        var rows: [[Int]]=[]
        for index in vertical {
            if let last=rows.last, let anchor=last.first, frames[index].minY-frames[anchor].minY <= 36 {
                rows[rows.count-1].append(index)
            } else { rows.append([index]) }
        }
        return rows.flatMap { row in row.sorted { frames[$0].minX == frames[$1].minX ? $0 < $1 : frames[$0].minX < frames[$1].minX } }
    }

    static func cocoaFrame(_ axFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: axFrame.minX, y: primaryScreenHeight - axFrame.maxY, width: axFrame.width, height: axFrame.height)
    }
}
