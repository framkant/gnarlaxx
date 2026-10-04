package scores

import "core:os"
import "core:strings"
import "core:strconv"
import "core:fmt"

COUNT :: 5
MAX_SCORE :: 999999999
Scores :: [COUNT]int
HEADER :: "GNARLAXX 1\n"

parse :: proc(data: string) -> (Scores, bool) {
    if !strings.has_prefix(data, HEADER) { return {}, false }
    remaining := data[len(HEADER): ]
    result: Scores
    for i in 0..<COUNT {
        line, ok := strings.split_lines_iterator(&remaining)
        if !ok { return {}, false }
        line = strings.trim_space(line)
        n: int
        score, valid := strconv.parse_int(line, 10, &n)
        if !valid || n != len(line) || score < 0 || score > MAX_SCORE || (i > 0 && score > result[i-1]) { return {}, false }
        result[i] = score
    }
    if len(strings.trim_space(remaining)) != 0 { return {}, false }
    return result, true
}

load :: proc(path: string) -> (Scores, bool) {
    data, ok := os.read_entire_file(path)
    if !ok { return {}, false }
    defer delete(data)
    return parse(string(data))
}

insert :: proc(scores: ^Scores, score: int) {
    if score < 1 || score > MAX_SCORE { return }
    for value, i in scores {
        if score > value {
            for j := COUNT-1; j>i; j -= 1 { scores[j] = scores[j-1] }
            scores[i] = score
            break
        }
    }
}

save :: proc(scores: Scores, path: string) -> bool {
    // Same atomic replacement and on-disk format as C. These strings live until
    // the caller resets its temporary allocator, after the operation returns.
    tmp := fmt.tprintf("%s.tmp", path)
    buffer: [len(HEADER)+COUNT*11]u8
    written := len(fmt.bprintf(buffer[: ],  "%s", HEADER))
    for score in scores { written += len(fmt.bprintf(buffer[written: ],  "%d\n", score)) }
    contents := string(buffer[: written])
    if !os.write_entire_file(tmp, transmute([]u8)contents) { os.remove(tmp); return false }
    if os.rename(tmp, path) { return true }
    os.remove(tmp)
    return false
}
