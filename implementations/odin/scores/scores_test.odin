package scores
import "core:testing"
import "core:fmt"
import "core:os"

@(test)
format_and_atomic_save :: proc(t: ^testing.T) {
    defer free_all(context.temp_allocator)
    values, ok := parse("GNARLAXX 1\n9000\n500\n0\n0\n0\n \t\n")
    testing.expect(t, ok && values == Scores{9000, 500, 0, 0, 0})
    insert(&values, 700); insert(&values, 0); insert(&values, MAX_SCORE+1)
    testing.expect(t, values == Scores{9000, 700, 500, 0, 0})
    invalid := []string{"",  "GNARLAXX 2\n1\n0\n0\n0\n0\n",  "GNARLAXX 1\n1\n2\n0\n0\n0\n",
        "GNARLAXX 1\n1x\n0\n0\n0\n0\n",  "GNARLAXX 1\n-1\n0\n0\n0\n0\n",
        "GNARLAXX 1\n1000000000\n0\n0\n0\n0\n",  "GNARLAXX 1\n1\n0\n0\n0\n",
        "GNARLAXX 1\n1\n0\n0\n0\n0\nextra"}
    for data in invalid { parsed, valid := parse(data); testing.expect(t, !valid && parsed == Scores{}) }
    path := fmt.tprintf("%s/odin-score-test.txt", #config(GNARLAXX_TEST_DIR,"build/odin"))
    defer os.remove(path)
    testing.expect(t, save(values, path))
    loaded, valid := load(path); testing.expect(t, valid && loaded == values)
    bytes, read := os.read_entire_file(path); defer delete(bytes)
    testing.expect(t, read && string(bytes) == "GNARLAXX 1\n9000\n700\n500\n0\n0\n")
    insert(&values, 9999); testing.expect(t, save(values, path))
    loaded, valid = load(path); testing.expect(t, valid && loaded == values)
    testing.expect(t, !save(values, fmt.tprintf("%s/missing", path)))
    loaded, valid = load(path); testing.expect(t, valid && loaded == values)
}
