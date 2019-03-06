//
//  Wax.swift
//  Vinyl
//
//  Created by Michael Brown on 07/08/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

struct Wax {

  var uniquelyRecord = true
  var tracks: [Track] = []

  init(vinyl: Vinyl) {
    tracks.append(contentsOf: vinyl.tracks)
  }

  init(tracks: [Track]) {
    self.tracks.append(contentsOf: tracks)
  }

  mutating func add(track: Track) {
    // don't save track if we are set up to uniquely record and we can the same request
    if uniquelyRecord && tracks.any { track.request == $0.request } {
      return
    }
    tracks.append(track)
  }
}
