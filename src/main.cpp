#include <iostream>
#include <utility>
#include <cstdlib>
#include <cmath>
#include <cassert>

void merge(int* out, int* xs, size_t l1, int* ys, size_t l2) {
	for (size_t i=0, j=0;;) {
		if (xs[i] < ys[j]) {
			out[i+j] = xs[i];
			if (i < l1)
				i+=1;
		} else {
			out[i+j] = ys[j];
			if (j < l2)
				j+=1;
		}
		
	}
}

void sort(int* xs, size_t len) {
	assert(len/2 + (len - len/2) == len);
	std::cout << "length = " << len << '\n';
	if (len <= 1) return;
	sort(xs, len/2);
	sort(xs + len/2, len - len/2);
	int* mem = new int[len];
	merge(mem, xs, len/2, xs + len/2, len - len/2);
	memcpy(xs, mem, len);
	delete[] mem;
}

int xs[70];

int main() {
	std::srand(time(0));
	for (int& x : xs) x = std::rand() % 200;
	sort(xs,std::size(xs));
	for (int i : xs) std::cout << i << ' ';
	std::cout << '\n';
	return 0;
}
