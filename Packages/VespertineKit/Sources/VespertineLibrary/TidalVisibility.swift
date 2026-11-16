// Vespertine: the master switch's reach into the library: what the queries return while TIDAL is off.
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

extension LibraryDatabase {
    /// Whether the TIDAL account's rows take part in the library's lists, counts, albums, artists, genres, favorites, history, playlists
    /// and smart playlists. The app sets it from Settings › Online › "TIDAL integration" (off by default, decision 209). Off, every query
    /// answers as if the library had never had a TIDAL account; nothing is deleted. A database nobody switched (the command-line
    /// tools, the sync) sees everything. It joins the music servers' rules (`hiddenSourceIDs`, `visibleTracksClause`,
    /// `visiblePlaylistsClause`): the TIDAL account is one more source those leave out while it is off.
    public var includeTidal: Bool {
        get { includesTidal.withLock { $0 } }
        set { includesTidal.withLock { $0 = newValue } }
    }

    /// The TIDAL account's source, if the library has one, whatever the switch says.
    public static func tidalAccount(_ db: Database) throws -> LibrarySource? {
        try LibrarySource.filter(Column("path") == LibrarySource.tidalPath).fetchOne(db)
    }

    /// The TIDAL account's source, if the library has one (it is never among `sources()`, which are folders, drives and shares).
    public func tidalAccount() throws -> LibrarySource? {
        try writer.read { db in try Self.tidalAccount(db) }
    }

    /// A condition on `track` rows (or the table `qualifier` names) that leaves TIDAL's rows out while TIDAL is off, for the reads
    /// that don't go through `visibleTracksClause` (the files to analyse, the bytes the files take): "1" while it is on.
    func tidalShownClause(qualifier: String = "track") -> String {
        includeTidal ? "1" : "\(qualifier).location NOT LIKE 'tidal://%'"
    }

    /// A condition on `playlist` rows: a playlist that stands for one of TIDAL's (`tidalPlaylist`, from the playlist sync) shows only
    /// while TIDAL is on.
    func tidalPlaylistsClause(_ db: Database) throws -> String {
        guard !includeTidal, try db.tableExists("tidalPlaylist") else { return "1" }
        return "id NOT IN (SELECT playlistId FROM tidalPlaylist)"
    }
}
