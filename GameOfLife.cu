
#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <chrono>

__global__ void manipulateSystem(bool *system, int M, int N) {
    int i, j, x, y, index, testCase = 0, neighbors = 0;
    bool temp;
    index = blockIdx.x * blockDim.x + threadIdx.x;

    if (index == 0) {                           //top left
        testCase = 5;
    } else if (index == M - 1){                 //top right
        testCase = 6;
    } else if (index == (M - 1) * N) {          //bottom left
        testCase = 7;
    } else if (index == M * N - 1) {            //bottom right
        testCase = 8;
    } else if (index % M == 0) {                //left
        testCase = 1;
    } else if (index % M == M - 1) {            //right
        testCase = 2;
    } else if (index > 0 && index < M) {        //top
        testCase = 3;
    } else if (index > (M - 1) * N) {           //bottom
        testCase = 4;
    } else {
        testCase = 0;
    }

    __syncthreads();
    switch (testCase) {
        case 0:         //center 
            for (i = index - M - 1; i < index + M; i+=M) {
                for (j = 0; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 1:         //left
            for (i = index - M - 1; i < index + M; i += M) {
                for (j = 1; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 2:         //right
            for (i = index - M - 1; i < index + M; i += M) {
                for (j = 0; j < 2; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 3:         //top
            for (i = index - 1; i < index + M; i += M) {
                for (j = 0; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 4:         //bottom
            for (i = index - M - 1; i < index; i += M) {
                for (j = 0; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 5:         //top left
            for (i = index - 1; i < index + M; i += M) {
                for (j = 1; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 6:         //top right
            for (i = index - 1; i < index + M; i += M) {
                for (j = 0; j < 2; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        case 7:         //bottom left
            for (i = index - M - 1; i < index; i += M) {
                for (j = 1; j < 3; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
        default:        //bottom right
            for (i = index - M - 1; i < index; i += M) {
                for (j = 0; j < 2; j++) {
                    if (*(system + i + j)) {
                        neighbors++;
                    }
                }
            }
            break;
    }
    
    if (*(system + index) && neighbors <= 1) {
        temp = 0;
    } else if (*(system + index) && neighbors >= 4) {
        temp = 0;
    } else if (!*(system + index) && (neighbors == 2 || neighbors == 3)) {
        temp = 1;
    } else {
        temp = *(system + index);
    }
    
    __syncthreads();
    *(system + index) = temp;
}

void genArray(bool *array, int M, int N) {
    int i, j;
    for (i = 0; i < M; i++) {
        for (j = 0; j < N; j++) {
            if (rand()%2 == 0) {
                *(array + i*M + j) = 1;
            } else {
                *(array + i*M + j) = 0;
            }
        }
    }
}

void printArray(bool *array, int M, int N) {
    int i, j;
    
    for (i = 0; i < M; i++) {
        for (j = 0; j < N; j++) {
            printf("%d ", *(array + i*M + j));
        }
        printf("\n");
    }
}

int main() {
    int i, j, M, N, K, iteration, size, execTime = 0, population;
    bool *system, debug = 0, *d_system;
    std::chrono::time_point<std::chrono::high_resolution_clock> gpuStart, gpuEnd;
    
    printf("Enter the number of rows (M): ");
    if (scanf("%d", &M)) {}
    printf("Enter the number of columns (N): ");
    if (scanf("%d", &N)) {}
    printf("Enter the number of iterations (K): ");
    if (scanf("%d", &K)) {}

    size = M * N;
    srand(time(NULL));

    system = (bool*)malloc(size * sizeof(bool*));
    
    cudaMalloc((void**)&d_system, size * sizeof(bool));


    genArray(system, M, N);
    printf("Initial System State:\n");
    printArray(system, M, N);

    population = 0;
    for (i = 0; i < M; i++) {
        for (j = 0; j < N; j++) {
            population += (int)*(system + i * M + j);
        }
    }
    printf("Population Density: %0.2f\n", 1.0 * population / size);

    cudaMemcpy(d_system, system, size*sizeof(bool), cudaMemcpyHostToDevice);

    
    for (iteration = 1; iteration <= K; iteration++) {
        population = 0;
        gpuStart = std::chrono::high_resolution_clock::now();
        manipulateSystem <<<M, N>>> (d_system, M, N);
        gpuEnd = std::chrono::high_resolution_clock::now();
        auto gpuTime = std::chrono::duration_cast<std::chrono::microseconds>(gpuEnd - gpuStart);
        execTime += gpuTime.count();
        cudaMemcpy(system, d_system, size*sizeof(bool), cudaMemcpyDeviceToHost);

        if (debug) {
            printf("iteration: %d\n", iteration);
            printArray(system, M, N);
            printf("Execution time: %d microseconds\n", gpuTime.count());
            for (i = 0; i < M; i++) {
                for (j = 0; j < N; j++) {
                    population += (int) *(system + i * M + j);
                }
            }
            printf("Population Density: %0.2f\n", 1.0 * population / size);
        }
    }

    printf("\nResult:\n");
    printArray(system, M, N);
    printf("Total Execution Time: %d microseconds\n", execTime);
    population = 0;
    for (i = 0; i < M; i++) {
        for (j = 0; j < N; j++) {
            population += (int)*(system + i * M + j);
        }
    }
    printf("Population Density: %0.2f\n", 1.0 * population / size);

    free(system);
    cudaFree(d_system);
    return 0;
}
