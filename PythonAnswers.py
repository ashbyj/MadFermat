import numpy as np

# this function took 20 minutes 
def build_and_sum_maxtrix():
    matrix_200 = np.random.randint(10, size=(200,200))
    matrix_total = 0
    
    for row in range(200):
        for column in range(200):
            matrix_total += matrix_200[row][column]

    print (f'matrix size: {len(matrix_200)}, {len(matrix_200[0])}')
    print (f'matrix total: {matrix_total}')
    
    return matrix_200

#this function does not work yet.  i have 3 hours into it so far
def row_redux(matrix):
    x = 0
    
    for y in range(200):
        if x == 200:
            break
            
        pivot_row = x  
        while pivot_row < 200 and matrix[pivot_row, y] == 0:
            pivot_row += 1
        if pivot_row == 200:
            continue
    
        matrix[[x, pivot_row]] = matrix[[pivot_row, x]]
        matrix[x] /= matrix[x, y]

        for i in range(200):
            if i != x and matrix[i, y] != 0:
                matrix[i] -= matrix[i, y] * matrix[x]

        x += 1
    return matrix


if __name__ == "__main__":
    matrix = build_and_sum_maxtrix()
    #rref_matrix = row_redux(matrix.copy())
    print ('random 200x200:')
    print(matrix)
    #print ('row reduced echelon form:')
    #print(rref_maxtrix)
