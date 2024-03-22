import numpy as np
np.random.seed(42)

# this function took 20 minutes 
def build_and_sum_maxtrix(rows, columns):
    matrix_f = np.random.randint(10, size=(rows, columns))
    matrix_sum = 0
    
    for row in range(rows):
        for column in range(columns):
            matrix_sum += matrix_f[row][column]

    print (f'matrix size: {len(matrix_f)}, {len(matrix_f[0])}')
    print (f'matrix sum: {matrix_sum}')
    print (matrix_f)
    
    return matrix_f

def row_redux(matrix):

    return_matrix = matrix.copy().astype(float)
    row_count = len(return_matrix)

   # run rref algo on every row
    for pivot_row in range(row_count):

        # divide the current row by its pivot value
        pivot_value = return_matrix[pivot_row][pivot_row]
        return_matrix[pivot_row] /= pivot_value

        # end the loop before trying to extend out of bounds
        if pivot_row == row_count:
            break

        for row in range(pivot_row + 1, row_count):            
            return_matrix[row] -= return_matrix[pivot_row] * pivot_value 
  
    return return_matrix

if __name__ == "__main__":
    matrix = build_and_sum_maxtrix(200, 200)
    print(row_redux(matrix))