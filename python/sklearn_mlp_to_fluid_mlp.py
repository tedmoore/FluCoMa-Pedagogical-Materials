from sklearn.neural_network import MLPRegressor

def mlpToFluidJsonDict(mlp):
    '''
    "layers":{ // layers are in feedforward order
        "activation": // int from FluidMLPRegressor //,
        "biases": biases for the layer (array of "cols" length)
        "cols": int num of neurons in this layer ,
        "rows": num inputs to this layer,
        "weights: array of "rows" arrays with "cols" items in each,
    }
    '''
    weights = mlp.coefs_
    biases = mlp.intercepts_
    json_dict = {"layers":[{} for _ in range(mlp.n_layers_ - 1)]}
    
    activation_map = {'identity':0,  'logistic':1,  'relu':2, 'tanh':3}
    acvtivation = activation_map[mlp.activation]

    for i, biases_array in enumerate(biases):
        # print('i',i)
        # print('len biases',len(biases))
        if i == (len(biases) - 1):
            json_dict["layers"][i]["activation"] = 0 # identity for the last layer
        else:
            json_dict["layers"][i]["activation"] = activation

        # print('inserted act',json["layers"][i]["activation"])
        # print('')
        
        json_dict["layers"][i]["biases"] = list(biases_array)
        json_dict["layers"][i]["cols"] = len(biases_array)
        json_dict["layers"][i]["rows"] = len(weights[i])
        json_dict["layers"][i]["weights"] = list([list(w) for w in weights[i]])
    return json_dict
