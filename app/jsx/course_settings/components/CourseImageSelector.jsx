define([
  'react',
  'react-modal',
  'i18n!course_images',
  '../actions',
  './CourseImagePicker'
], (React, Modal, I18n, Actions, CourseImagePicker) => {

  class CourseImageSelector extends React.Component {

    constructor (props) {
      super(props);
      this.state = props.store.getState();

      this.handleChange = this.handleChange.bind(this);
      this.handleModalClose = this.handleModalClose.bind(this);
    }

    componentWillMount () {
      this.props.store.subscribe(this.handleChange);
      this.props.store.dispatch(Actions.getCourseImage(this.props.courseId));
    }

    handleChange () {
      this.setState(this.props.store.getState());
    }

    handleModalClose () {
      this.props.store.dispatch(Actions.setModalVisibility(false));
    }

    render () {

      const styles = {
        backgroundImage: `url(${this.state.imageUrl})`
      };

      return (
        <div>
          <input
            ref="hiddenInput"
            type="hidden"
            name={this.state.hiddenInputName}
            value={this.state.courseImage}
          />
          <div
            className="CourseImageSelector"
            style={(this.state.imageUrl) ? styles : {}}
          >
            <button
              className="Button"
              type="button"
              onClick={() => this.props.store.dispatch(Actions.setModalVisibility(true))}
            >
              {I18n.t('Change Image')}
            </button>
          </div>
          <Modal
            className="CourseImageSelector__Modal"
            isOpen={this.state.showModal}
            onRequestClose={this.handleModalClose}
          >
            <CourseImagePicker
              courseId={this.props.courseId}
              handleClose={this.handleModalClose}
              handleFileUpload={(e, courseId) => this.props.store.dispatch(Actions.uploadFile(e, courseId))}
            />
          </Modal>
        </div>
      );
    }
  };

  return CourseImageSelector;

});