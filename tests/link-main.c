/* Links against out/link.o: `both` is compiled code, `helper` is what it calls. */
#include <stdint.h>
#include <stdio.h>

uint64_t both(uint64_t x);

uint64_t helper(uint64_t a) { return a * 7 - 2; }

int main(void) {
  int failures = 0;
  for (uint64_t i = 0; i < 50; i++) {
    uint64_t x = i * 977;
    uint64_t a = x * 3 + 1, b = helper(x + 1), c = b * 3 + 1;
    if (both(x) != a + b + c) failures++;
  }
  printf("linked by the system linker: %d failures\n", failures);
  return failures != 0;
}
