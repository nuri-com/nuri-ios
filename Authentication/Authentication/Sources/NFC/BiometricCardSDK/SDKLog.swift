import Foundation

struct SDKLog: TextOutputStream {

    func getLog(_ string:String) -> String{
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: Date())
        return "\(timeString) - \(string)\n"
    }

    public mutating func write(_ string: String) {
        let currentDate = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let day = calendar.component(.day, from: currentDate)
        let formattedDate = "\(year)_\(month)_\(day)"

        let paths = FileManager.default.urls(for: .documentDirectory, in: .allDomainsMask)
        let documentDirectoryPath = paths.first!
        let log = documentDirectoryPath.appendingPathComponent("sdk_log_" + formattedDate + ".txt")

        if !FileManager.default.fileExists(atPath: log.path) {
            do {
                try getLog(string).write(to: log, atomically: true, encoding: .utf8)
            } catch {
                print("Error creating file: \(error.localizedDescription)")
            }
        }
        else {
            do {
                let handle = try FileHandle(forWritingTo: log)
                handle.seekToEndOfFile()
                handle.write(getLog(string).data(using: .utf8)!)
                handle.closeFile()
            } catch {
                print(error.localizedDescription)
                do {
                    try getLog(string).data(using: .utf8)?.write(to: log)
                } catch {
                    print(error.localizedDescription)
                }
            }
        }

        print(string)
    }

}
