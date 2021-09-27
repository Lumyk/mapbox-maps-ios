import Foundation
import MapboxCommon
import CoreLocation

// MARK: - Geometry

public typealias Geometry = Turf.Geometry

extension MapboxCommon.Geometry {

    /// Allows a `Geometry` object to be initialized with a `Geometry` object.
    /// - Parameter geometry: The `Geometry` object to transform into the `Geometry` type.
    internal convenience init(geometry: Geometry) {
        switch geometry {
        case .point(let point):
            let coordinate = point.coordinates
            self.init(coordinate: coordinate)

        case .lineString(let line):
            self.init(line: line.coordinates)

        case .polygon(let polygon):
            self.init(polygon: polygon.coordinates)

        case .multiPoint(let multiPoint):
            self.init(multiPoint: multiPoint.coordinates)

        case .multiLineString(let multiLine):
            self.init(multiLine: multiLine.coordinates)

        case .multiPolygon(let multiPolygon):
            self.init(multiPolygon: multiPolygon.coordinates)

        case .geometryCollection(let geometryCollection):
            let geometryValues = geometryCollection.geometries.map {( MapboxCommon.Geometry(geometry: $0) )}
            self.init(geometryCollection: geometryValues)

        #if USING_TURF_WITH_LIBRARY_EVOLUTION
        @unknown default:
            fatalError("Could not determine Geometry from given Turf Geometry")
        #endif
        }
    }

    /// Initialize a `Geometry` point from a coordinate.
    /// - Parameter coordinate: The coordinate to represent the `Geometry` point.
    private convenience init(coordinate: CLLocationCoordinate2D) {
        let pointValue = coordinate.toValue()
        self.init(point: pointValue)
    }

    /// Initialize a `Geometry` line from an array of coordinates.
    /// - Parameter coordinates: The coordinates to represent the `Geometry` line.
    private convenience init(line coordinates: [CLLocationCoordinate2D]) {
        let lineValues = CLLocationCoordinate2D.convertToValues(from: coordinates)
        self.init(line: lineValues)
    }

    /// Initialize a `Geometry` polygon from a two-dimensional array of coordinates.
    /// - Parameter coordinates: The coordinates to represent the `Geometry` polygon.
    private convenience init(polygon coordinates: [[CLLocationCoordinate2D]]) {
        let polygons = coordinates.map({ CLLocationCoordinate2D.convertToValues(from: $0) })
        self.init(polygon: polygons)
    }

    /// Initialize a `Geometry` multipoint from an array of `CLLocationCoordinate`s.
    /// - Parameter coordinates: The coordinates to represent the `Geometry` multipoint.
    private convenience init(multiPoint coordinates: [CLLocationCoordinate2D]) {
        let multiPointValue = coordinates.map({ $0.toValue() })
        self.init(multiPoint: multiPointValue)
    }

    /// Initialize a `Geometry` multiline from a two-dimensional array of `CLLocationCoordinate`s.
    /// - Parameter coordinates: The coordinates to represent the `Geometry` multiline.
    private convenience init(multiLine coordinates: [[CLLocationCoordinate2D]]) {
        let multiLineValues = coordinates.map({ CLLocationCoordinate2D.convertToValues(from: $0) })
        self.init(multiLine: multiLineValues)
    }

    /// Initialize a `Geometry` multipolygon from a three-dimensional array of `CLLocationCoordinate`s.
    /// - Parameter coordinates: The coordinates to represent the `Geometry` multipolygon.
    private convenience init(multiPolygon coordinates: [[[CLLocationCoordinate2D]]]) {
        let multiPolygonValues = coordinates.map({
            $0.map({ CLLocationCoordinate2D.convertToValues(from: $0) })
        })
        self.init(multiPolygon: multiPolygonValues)
    }
}
