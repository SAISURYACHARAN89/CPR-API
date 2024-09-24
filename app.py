from flask import Flask, request, render_template
import pandas as pd
import subprocess

app = Flask(__name__)

@app.route('/', methods=['GET', 'POST'])
def index():
    recommendations = None
    message = None  # Initialize message for error or info
    if request.method == 'POST':
        customer_id = request.form['customer_id']

        try:
            subprocess.run(['Rscript', 'model/model.r', str(customer_id)], check=True)
            recommended_products = pd.read_csv('model/recommended_products.csv')

            if 'Message' in recommended_products:
                message = recommended_products['Message'].iloc[0]
            else:
                # Convert DataFrame to a list of tuples for rendering
                recommendations = recommended_products.to_dict(orient='records')

        except subprocess.CalledProcessError:
            message = "Error occurred while calling the R script."
        except FileNotFoundError:
            message = "The R script or output file was not found."
        except Exception as e:
            message = f"An error occurred: {str(e)}"

    return render_template('index.html', recommendations=recommendations, message=message)

if __name__ == '__main__':
    app.run(debug=True)
