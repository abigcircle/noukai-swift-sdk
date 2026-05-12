import Foundation

/// Configuration for connecting to the noukai API. Produces the slug-execution
/// URL (`/api/v1/seq/{org}/{project}/{flow}/execute`) and optionally appends a
/// `?version=N` query parameter when a specific flow version is targeted.
///
/// Noukai runs the agent loop server-side and pauses when tool calls are needed;
/// the client executes tools locally and resumes with results.
public struct NoukaiConfiguration: Sendable, Equatable {
    /// The base URL of the noukai API, e.g. `https://api.noukai.xyz`.
    public let baseURL: URL

    /// The organisation slug, e.g. `"abc"`.
    public let org: String

    /// The project slug, e.g. `"po"`.
    public let project: String

    /// The flow slug, e.g. `"agent-loop"`.
    public let flow: String

    /// An optional flow version. When non-nil it is appended as `?version=N`.
    public let version: Int?

    /// Creates a noukai configuration.
    ///
    /// - Parameters:
    ///   - baseURL: API base URL. Defaults to `https://api.noukai.xyz`.
    ///   - org: Organisation slug.
    ///   - project: Project slug. Defaults to `"po"`.
    ///   - flow: Flow slug. Defaults to `"agent-loop"`.
    ///   - version: Optional flow version sent as a query parameter.
    public init(
        baseURL: URL = URL(string: "https://api.noukai.xyz")!,
        org: String,
        project: String = "po",
        flow: String = "agent-loop",
        version: Int? = nil
    ) {
        self.baseURL = baseURL
        self.org = org
        self.project = project
        self.flow = flow
        self.version = version
    }

    /// The full URL for the `/execute` endpoint, including a `?version=N`
    /// query parameter when `version` is non-nil.
    ///
    /// Pattern: `{baseURL}/api/v1/seq/{org}/{project}/{flow}/execute`
    public var executeURL: URL {
        let base = baseURL
            .appendingPathComponent("api/v1/seq")
            .appendingPathComponent(org)
            .appendingPathComponent(project)
            .appendingPathComponent(flow)
            .appendingPathComponent("execute")

        guard let v = version else { return base }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "version", value: "\(v)")]
        return components?.url ?? base
    }
}
