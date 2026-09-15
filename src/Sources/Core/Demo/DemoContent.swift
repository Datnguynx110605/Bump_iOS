#if DEBUG
import Foundation

/// The canned world the App Store screenshots are captured in.
///
/// Sized to the shot list and nothing more: five people, five shops, five feed posts, six
/// grid posts, four comments and four notifications is exactly enough to fill every screen
/// that gets captured — a feed that scrolls for a preview, a two-row profile grid, a
/// browsable shop list — without maintaining a world nobody photographs.
///
/// Written as data rather than as static JSON for one reason: **timestamps**. The feed
/// renders relative dates ("2h ago"), so fixed dates would drift to "6 months ago" the
/// next time anyone re-captures. Everything here is an offset from launch, so every run
/// produces the same plausible spread.
///
/// All copy is English. Shop names and captions are fixture data, not localized strings,
/// so they are identical in the English and Vietnamese captures — which is correct:
/// a real venue's name isn't translated between store listings.
enum DemoContent {
    // Stable ids so cross-references (a post's author, a notification's target) line up.
    static let viewerId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "%08x-0000-4000-8000-000000000000", n))!
    }

    struct Person {
        let id: UUID
        let name: String
        let bio: String?
        let photo: String?
        let followers: Int
        let following: Int
    }

    struct Shop {
        let id: UUID
        let name: String
        let address: String
        let rate: Int
    }

    struct Post {
        let id: UUID
        let author: UUID
        let shop: UUID
        let photos: [String]
        let caption: String
        let rate: Int
        let likes: Int
        let comments: Int
        /// Hours before launch.
        let age: Double
        let isLiked: Bool
        let isSaved: Bool
    }

    // MARK: - People

    static let viewer = Person(
        id: viewerId,
        name: "elliemarsh",
        bio: "Chasing the best flat white in the city. Usually at a corner table.",
        photo: "avatar-01.jpg",
        followers: 1284,
        following: 312
    )

    static let people: [Person] = [
        viewer,
        Person(id: id(2), name: "jonahreid", bio: "Brunch person. Will queue.", photo: "avatar-02.jpg", followers: 842, following: 190),
        Person(id: id(3), name: "priyanair", bio: "Ramen, noodles, anything in a bowl.", photo: "avatar-03.jpg", followers: 2130, following: 88),
        Person(id: id(4), name: "theowalsh", bio: "Pastry-first decision making.", photo: "avatar-04.jpg", followers: 517, following: 402),
        Person(id: id(5), name: "noracamp", bio: "Cocktails and late menus.", photo: "avatar-05.jpg", followers: 1965, following: 231),
    ]

    static func person(_ pid: UUID) -> Person { people.first { $0.id == pid } ?? viewer }

    // MARK: - Shops

    static let shops: [Shop] = [
        Shop(id: id(11), name: "The Workshop Coffee", address: "27 Marlowe Street, Old Town", rate: 5),
        Shop(id: id(12), name: "Fernwood Tea House", address: "40 Alder Lane, Riverside", rate: 4),
        Shop(id: id(13), name: "Sunday Morning Kitchen", address: "26 Bell Street, Old Town", rate: 5),
        Shop(id: id(14), name: "Ichiban Ramen Bar", address: "12 Harbour Walk, Docklands", rate: 4),
        Shop(id: id(15), name: "Early Loaf Bakery", address: "91 Sycamore Road, Northgate", rate: 5),
    ]

    static func shop(_ sid: UUID) -> Shop { shops.first { $0.id == sid } ?? shops[0] }

    // MARK: - Feed

    static let posts: [Post] = [
        Post(id: id(21), author: id(2), shop: id(11), photos: ["photo-01.jpg", "photo-02.jpg"],
             caption: "Corner table, oat flat white, zero rush. The kind of place you stay an hour longer than planned.",
             rate: 5, likes: 342, comments: 18, age: 0.6, isLiked: true, isSaved: false),

        Post(id: id(22), author: id(3), shop: id(14), photos: ["photo-03.jpg"],
             caption: "Broth so good I forgot to take a second photo. Go before seven or you're queueing.",
             rate: 5, likes: 918, comments: 64, age: 3, isLiked: false, isSaved: true),

        Post(id: id(23), author: id(4), shop: id(15), photos: ["photo-04.jpg", "photo-05.jpg"],
             caption: "Still warm at seven in the morning. The pistachio one is the move.",
             rate: 4, likes: 205, comments: 11, age: 8, isLiked: false, isSaved: false),

        Post(id: id(24), author: id(5), shop: id(12), photos: ["photo-06.jpg"],
             caption: "Quiet upstairs, proper ice, no queue after ten.",
             rate: 4, likes: 476, comments: 23, age: 26, isLiked: true, isSaved: false),

        Post(id: id(25), author: id(2), shop: id(13), photos: ["photo-08.jpg"],
             caption: "Eggs done properly and nobody rushing you out. Worth the queue.",
             rate: 5, likes: 1502, comments: 96, age: 50, isLiked: false, isSaved: true),
    ]

    /// Six, because the Profile grid is three across and two full rows photograph better
    /// than one row and a gap.
    static let myPosts: [Post] = [
        Post(id: id(31), author: viewerId, shop: id(11), photos: ["photo-02.jpg"], caption: "Morning ritual.", rate: 5, likes: 214, comments: 9, age: 5, isLiked: false, isSaved: false),
        Post(id: id(32), author: viewerId, shop: id(13), photos: ["photo-08.jpg"], caption: "The queue is the point.", rate: 5, likes: 402, comments: 22, age: 30, isLiked: false, isSaved: false),
        Post(id: id(33), author: viewerId, shop: id(15), photos: ["photo-04.jpg"], caption: "Early enough for the good ones.", rate: 4, likes: 118, comments: 4, age: 54, isLiked: false, isSaved: false),
        Post(id: id(34), author: viewerId, shop: id(14), photos: ["photo-03.jpg"], caption: "Rainy day order.", rate: 5, likes: 267, comments: 12, age: 78, isLiked: false, isSaved: false),
        Post(id: id(35), author: viewerId, shop: id(12), photos: ["photo-07.jpg"], caption: "Courtyard seat, four o'clock.", rate: 4, likes: 96, comments: 3, age: 102, isLiked: false, isSaved: false),
        Post(id: id(36), author: viewerId, shop: id(15), photos: ["photo-10.jpg"], caption: "Barely sweet, gone in four minutes.", rate: 4, likes: 150, comments: 6, age: 126, isLiked: false, isSaved: false),
    ]

    /// Extra posts that exist only to fill a shop's grid.
    ///
    /// Kept out of `posts` on purpose: the feed is five items by design, but a shop page
    /// with one photo on it photographs as an empty app rather than a busy one.
    static let galleryPosts: [Post] = [
        Post(id: id(41), author: id(3), shop: id(11), photos: ["photo-09.jpg"], caption: "Second visit this week.", rate: 5, likes: 288, comments: 14, age: 20, isLiked: false, isSaved: false),
        Post(id: id(42), author: id(4), shop: id(11), photos: ["photo-07.jpg"], caption: "Good light until about four.", rate: 5, likes: 176, comments: 8, age: 44, isLiked: false, isSaved: false),
        Post(id: id(43), author: id(5), shop: id(11), photos: ["photo-05.jpg"], caption: "They do a pastry too.", rate: 4, likes: 132, comments: 5, age: 68, isLiked: false, isSaved: false),
        Post(id: id(44), author: id(2), shop: id(11), photos: ["photo-10.jpg"], caption: "Small menu, all of it good.", rate: 5, likes: 341, comments: 17, age: 92, isLiked: false, isSaved: false),
        Post(id: id(45), author: id(3), shop: id(11), photos: ["photo-04.jpg"], caption: "Back again.", rate: 5, likes: 204, comments: 6, age: 116, isLiked: false, isSaved: false),
    ]

    // MARK: - Comments on the hero post

    struct Comment {
        let id: UUID
        let author: UUID
        let text: String
        let likes: Int
        let age: Double
    }

    static let comments: [Comment] = [
        Comment(id: id(41), author: id(3), text: "That corner table is the best seat in the city. Nobody tell anyone.", likes: 24, age: 0.4),
        Comment(id: id(42), author: id(5), text: "Going Saturday — do they take cards?", likes: 3, age: 0.3),
        Comment(id: id(43), author: id(4), text: "The oat flat white is genuinely the best I've had here.", likes: 11, age: 0.2),
        Comment(id: id(44), author: viewerId, text: "Adding it to my list right now.", likes: 1, age: 0.1),
    ]

    // MARK: - Notifications

    struct Note {
        let id: UUID
        let title: String
        let content: String
        let type: Int
        let target: UUID
        let actor: UUID
        let age: Double
    }

    static let notifications: [Note] = [
        Note(id: id(51), title: "priyanair liked your post", content: "Morning ritual.", type: 1, target: id(31), actor: id(3), age: 0.2),
        Note(id: id(52), title: "theowalsh started following you", content: "Say hello back.", type: 0, target: id(4), actor: id(4), age: 0.9),
        Note(id: id(53), title: "jonahreid commented", content: "Where is this? I need to go.", type: 3, target: id(31), actor: id(2), age: 2),
        Note(id: id(54), title: "noracamp liked your comment", content: "The queue is the point.", type: 2, target: id(32), actor: id(5), age: 6),
    ]
}
#endif
