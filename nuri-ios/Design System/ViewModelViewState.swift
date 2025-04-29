public protocol EmptyStateProviding {
    static var empty: Self { get }
}

public typealias ViewModelViewState = EmptyStateProviding & Equatable
